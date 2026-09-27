import AuthenticationServices
import Foundation
import UIKit

/// Encadena las dos fases de cada ceremonia WebAuthn:
/// pedir el reto al servidor → firmarlo con la passkey → devolverlo para verificar.
@MainActor
@Observable
final class AuthViewModel {
    private(set) var isWorking = false
    var errorMessage: String?

    private let api: APIClient
    private let passkeys: PasskeyService
    private let session: SessionViewModel

    init(session: SessionViewModel, api: APIClient = .shared, passkeys: PasskeyService = PasskeyService()) {
        self.session = session
        self.api = api
        self.passkeys = passkeys
    }

    /// Un solo boton para todo: si la persona ya tiene passkey entra, y si no la
    /// tiene se crea la cuenta. Primero se intenta entrar con las credenciales
    /// que YA hay disponibles, sin abrir ninguna hoja. Si iOS contesta al
    /// instante que no hay ninguna, se pasa al alta. Una hoja de Face ID que la
    /// persona cancela tarda mucho mas que eso, y entonces no se hace nada.
    func continueWithPasskey() async {
        let start = ContinuousClock.now
        let outcome = await perform { try await self.signInCeremony() }
        if outcome == .canceled, ContinuousClock.now - start < .milliseconds(800) {
            await perform { try await self.registerCeremony() }
        }
    }

    private func registerCeremony() async throws -> AuthResponse {
        let options: ChallengeResponse = try await api.send(.registrationOptions)
        let challenge = try PasskeyService.challengeData(from: options.publicKey.challenge)
        let name = options.publicKey.user?.name ?? "Friends"

        let authorization = try await passkeys.register(
            challenge: challenge,
            userID: Data((options.publicKey.user?.id ?? UUID().uuidString).utf8),
            name: name
        )

        guard let credential = authorization.credential
                as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PasskeyService.CredentialError.unexpectedCredentialType
        }

        return try await api.send(
            .registration,
            body: CredentialSubmission(
                challengeToken: options.challengeToken,
                credential: PasskeyService.payload(from: credential),
                deviceName: UIDevice.current.name
            ),
            snakeCase: false
        )
    }

    private func signInCeremony() async throws -> AuthResponse {
        let options: ChallengeResponse = try await api.send(.sessionOptions)
        let challenge = try PasskeyService.challengeData(from: options.publicKey.challenge)

        let authorization = try await passkeys.signIn(challenge: challenge)

        guard let credential = authorization.credential
                as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyService.CredentialError.unexpectedCredentialType
        }

        return try await api.send(
            .session,
            body: CredentialSubmission(
                challengeToken: options.challengeToken,
                credential: PasskeyService.payload(from: credential),
                deviceName: UIDevice.current.name
            ),
            snakeCase: false
        )
    }

    #if DEBUG
    /// Cuenta con la que entra el atajo de desarrollo.
    ///
    /// Configurable para poder probar de verdad lo que hace falta entre DOS
    /// personas (match, chat, bloqueo): se lanzan dos simuladores con handles
    /// distintos. Por argumento de lanzamiento `-DevHandle u_dev2`, por la
    /// variable de entorno `DEV_HANDLE`, o `u_dev` si no se dice nada.
    static var developmentHandle: String { explicitDevelopmentHandle ?? "u_dev" }

    /// Solo hay atajo si alguien lo pidio: la pantalla de entrada ya no tiene
    /// boton de prueba, asi que sin handle explicito se ve la puerta real.
    static var explicitDevelopmentHandle: String? {
        let candidates = [
            ProcessInfo.processInfo.environment["DEV_HANDLE"],
            UserDefaults.standard.string(forKey: "DevHandle")
        ]
        for candidate in candidates {
            let handle = candidate?.trimmingCharacters(in: .whitespaces) ?? ""
            if !handle.isEmpty { return handle }
        }
        return nil
    }

    /// Atajo de desarrollo: pide una sesion al servidor sin passkey.
    /// El endpoint no existe en produccion.
    func signInForDevelopment() async {
        await perform {
            try await self.api.send(.devSession, body: DevSessionRequest(handle: Self.developmentHandle))
        }
    }
    #endif

    // MARK: -

    enum Outcome { case signedIn, canceled, failed, busy }

    @discardableResult
    private func perform(_ ceremony: @escaping () async throws -> AuthResponse) async -> Outcome {
        guard !isWorking else { return .busy }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await ceremony()
            await SessionStore.shared.store(response.token)
            session.didSignIn(needsOnboarding: !response.user.onboardingCompleted)
            return .signedIn
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // El usuario cerro la hoja de Face ID (o no habia ninguna passkey):
            // no es un error que mostrar.
            return .canceled
        } catch {
            errorMessage = Self.describe(error)
            return .failed
        }
    }

    private static func describe(_ error: any Error) -> String {
        // Build sin firmar: ASAuthorization no puede operar sin application
        // identifier. Pasa siempre hasta que haya cuenta de Apple Developer,
        // asi que se explica en lugar de mostrar el texto de Apple.
        if (error as NSError).localizedDescription.contains("application identifier") {
            return "Las passkeys necesitan que la app este firmada con una cuenta de Apple Developer."
        }

        return switch error {
        case let apiError as APIError:
            switch apiError {
            case .offline:                   "Sin conexion. Intentalo de nuevo."
            case .server(_, let message):    message
            case .unauthorized:              "La passkey no es valida."
            default:                         "No se pudo completar. Intentalo de nuevo."
            }
        case let localized as any LocalizedError:
            localized.errorDescription ?? "No se pudo completar."
        default:
            (error as NSError).localizedDescription
        }
    }
}
