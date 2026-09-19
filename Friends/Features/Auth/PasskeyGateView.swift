import SwiftUI

/// Puerta de entrada: el acceso es siempre con passkey.
struct PasskeyGateView: View {
    let session: SessionViewModel
    @State private var model: AuthViewModel?

    var body: some View {
        ZStack {
            DoodleBackground()

            VStack(spacing: 28) {
                Spacer()

                Text("FRIENDS")
                    .font(.lazyDisplay)
                    .kerning(4)
                    .foregroundStyle(Color.lazyBlack)

                Text("Citas y amistades.\nTu passkey es tu cuenta.")
                    .font(.lazyBody)
                    .foregroundStyle(Color.lazyBlack)
                    .multilineTextAlignment(.center)

                Spacer()

                if let message = model?.errorMessage {
                    Text(message)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.lazyBlack)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .lazyCard(backgroundColor: .lazyNotice, cornerRadius: 16, offset: 3)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 14) {
                    Button("Crear cuenta con passkey") {
                        Task { await model?.register() }
                    }
                    .buttonStyle(LazyButtonStyle(background: .lazyRed, foreground: .white, fillsWidth: true))

                    Button("Entrar con mi passkey") {
                        Task { await model?.signIn() }
                    }
                    .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack, fillsWidth: true))
                }
                .disabled(model?.isWorking ?? true)
                .opacity((model?.isWorking ?? false) ? 0.5 : 1)

                #if DEBUG
                // Las passkeys necesitan un dominio asociado firmado con una
                // cuenta de Apple Developer. Mientras no la haya, esta puerta
                // trasera deja seguir construyendo el resto de la app.
                Button("Entrar sin passkey (dev)") {
                    Task { await model?.signInForDevelopment() }
                }
                .buttonStyle(LazyButtonStyle(background: .lazyMint, foreground: .lazyBlack, fillsWidth: true))
                .padding(.top, 4)
                #endif

                Text("PASSKEY · FACE ID")
                    .font(.lazyMono)
                    .foregroundStyle(Color.lazyBlack.opacity(0.65))
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
            .padding(.trailing, 5)
            .animation(.snappy, value: model?.errorMessage)
        }
        .task {
            if model == nil { model = AuthViewModel(session: session) }
        }
    }
}
