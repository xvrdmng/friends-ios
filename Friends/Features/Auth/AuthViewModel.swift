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

    func register() async {
        await perform {
            let options: ChallengeResponse = try await self.api.send(.registrationOptions)
            let challenge = try PasskeyService.challengeData(from: options.publicKey.challenge)
            let name = options.publicKey.user?.name ?? "Friends"

            let authorization = try await self.passkeys.register(
                challenge: challenge,
                userID: Data((options.publicKey.user?.id ?? UUID().uuidString).utf8),
                name: name
            )

            guard let credential = authorization.credential
                    as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
                throw PasskeyService.CredentialError.unexpectedCredentialType
            }

            let response: AuthResponse = try await self.api.send(
                .registration,
                body: CredentialSubmission(
                    challengeToken: options.challengeToken,
                    credential: PasskeyService.payload(from: credential),
                    deviceName: UIDevice.current.name
                ),
                snakeCase: false
            )
            return response
        }
    }

    func signIn() async {
        await perform {
            let options: ChallengeResponse = try await self.api.send(.sessionOptions)
            let challenge = try PasskeyService.challengeData(from: options.publicKey.challenge)

            let authorization = try await self.passkeys.signIn(challenge: challenge)

            guard let credential = authorization.credential
                    as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
                throw PasskeyService.CredentialError.unexpectedCredentialType
            }

            let response: AuthResponse = try await self.api.send(
                .session,
                body: CredentialSubmission(
                    challengeToken: options.challengeToken,
                    credential: PasskeyService.payload(from: credential),
                    deviceName: UIDevice.current.name
                ),
                snakeCase: false
            )
            return response
        }
    }

    #if DEBUG
    /// Cuenta con la que entra el atajo de desarrollo.
    ///
    /// Configurable para poder probar de verdad lo que hace falta entre DOS
    /// personas (match, chat, bloqueo): se lanzan dos simuladores con handles
    /// distintos. Por argumento de lanzamiento `-DevHandle u_dev2`, por la
    /// variable de entorno `DEV_HANDLE`, o `u_dev` si no se dice nada.
    static var developmentHandle: String {
        let candidates = [
            ProcessInfo.processInfo.environment["DEV_HANDLE"],
            UserDefaults.standard.string(forKey: "DevHandle")
        ]
        for candidate in candidates {
            let handle = candidate?.trimmingCharacters(in: .whitespaces) ?? ""
            if !handle.isEmpty { return handle }
        }
        return "u_dev"
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

    private func perform(_ ceremony: @escaping () async throws -> AuthResponse) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await ceremony()
            await SessionStore.shared.store(response.token)
            session.didSignIn(needsOnboarding: !response.user.onboardingCompleted)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // El usuario cerro la hoja de Face ID: no es un error que mostrar.
            return
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    private static func describe(_ error: any Error) -> String {
        // Build sin firmar: ASAuthorization no puede operar sin application
        // identifier. Pasa siempre hasta que haya cuenta de Apple Developer,
        // asi que se explica en lugar de mostrar el texto de Apple.
        if (error as NSError).localizedDescription.contains("application identifier") {
            return "Las passkeys necesitan una cuenta de Apple Developer para firmar la app. Usa \"Entrar sin passkey (dev)\" mientras tanto."
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
