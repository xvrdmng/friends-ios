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
                case .signedIn:     RootView()
                }
            }
            .task { await session.restore() }
        }
    }
}

/// Estado de sesión de la app. `onboarding` es un estado propio porque el wizard
/// es reanudable: si el usuario cierra la app a medias, vuelve al mismo paso.
@MainActor
@Observable
final class SessionViewModel {
    enum State { case loading, signedOut, onboarding, signedIn }
    private(set) var state: State = .loading

    func restore() async {
        guard await SessionStore.shared.isSignedIn else {
            state = .signedOut
            return
        }
        // TODO(M1): GET /me y decidir entre .onboarding y .signedIn según
        // onboarding_completed_at.
        state = .signedIn
    }

    func didSignIn(needsOnboarding: Bool) {
        state = needsOnboarding ? .onboarding : .signedIn
    }

    func signOut() async {
        await SessionStore.shared.clear()
        state = .signedOut
    }
}
