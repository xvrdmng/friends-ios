import SwiftUI

@main
struct FriendsApp: App {
    @State private var session = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:      SplashView()
                case .signedOut:    PasskeyGateView(session: session)
                case .onboarding:   OnboardingWizardView(session: session)
                case .signedIn:     RootView(session: session)
                }
            }
            .task { await session.restore() }
        }
    }
}

/// Estado de sesión de la app. `onboarding` es un estado propio porque el wizard
/// es reanudable: si el usuario cierra la app a medias, vuelve al mismo paso.
///
/// La sesion persiste en el Keychain (ver `SessionStore`); al abrir la app se
/// valida contra el servidor con GET /me.
@MainActor
@Observable
final class SessionViewModel {
    enum State { case loading, signedOut, onboarding, signedIn }
    private(set) var state: State = .loading

    /// Perfil del servidor, para que el wizard retome donde se quedo.
    private(set) var me: MeResponse?

    private static let onboardedKey = "session.onboardingCompleted"

    func restore() async {
        guard await SessionStore.shared.isSignedIn else {
            state = .signedOut
            return
        }

        do {
            let me: MeResponse = try await APIClient.shared.send(.me)
            self.me = me
            UserDefaults.standard.set(me.user.onboardingCompleted, forKey: Self.onboardedKey)
            state = me.user.onboardingCompleted ? .signedIn : .onboarding
        } catch APIError.unauthorized {
            // Token caducado o revocado: APIClient ya lo borro del Keychain.
            state = .signedOut
        } catch {
            // Sin red o servidor caido: no se expulsa al usuario. Se usa lo
            // ultimo que se supo del onboarding.
            let onboarded = UserDefaults.standard.bool(forKey: Self.onboardedKey)
            state = onboarded ? .signedIn : .onboarding
        }
    }

    func didSignIn(needsOnboarding: Bool) {
        UserDefaults.standard.set(!needsOnboarding, forKey: Self.onboardedKey)
        // El perfil se pide otra vez para retomar el wizard con datos frescos.
        Task { await restore() }
    }

    func didCompleteOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
        state = .signedIn
    }

    /// Revoca el token en el servidor (mejor esfuerzo) y lo borra del Keychain.
    func signOut() async {
        try? await APIClient.shared.send(.signOut)
        await SessionStore.shared.clear()
        UserDefaults.standard.removeObject(forKey: Self.onboardedKey)
        me = nil
        state = .signedOut
    }
}
