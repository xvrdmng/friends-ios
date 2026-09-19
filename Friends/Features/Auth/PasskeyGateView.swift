import SwiftUI

/// Puerta de entrada: no hay contraseñas ni email, solo passkey.
struct PasskeyGateView: View {
    let session: SessionViewModel
    @State private var isWorking = false

    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("FRIENDS")
                    .font(.lazyDisplay)
                    .kerning(-1.5)

                Text("Citas y amistades sin contraseñas.")
                    .font(.lazyBody)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 14) {
                    Button("Crear cuenta") { Task { await register() } }
                        .buttonStyle(LazyButtonStyle(background: .lazyAcid, foreground: .lazyBlack))

                    Button("Ya tengo cuenta") { Task { await signIn() } }
                        .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack))
                }
                .disabled(isWorking)

                Text("USA FACE ID · SIN CONTRASEÑAS")
                    .font(.lazyMono)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
    }

    // TODO(M1): encadenar con /auth/registration/options y /auth/registration.
    private func register() async {
        isWorking = true
        isWorking = false
    }

    private func signIn() async {
        isWorking = true
        isWorking = false
    }
}
