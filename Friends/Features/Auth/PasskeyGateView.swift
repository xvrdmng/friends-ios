import SwiftUI

/// Puerta de entrada: el acceso es siempre con passkey.
struct PasskeyGateView: View {
    let session: SessionViewModel
    @State private var model: AuthViewModel?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                Text("Friends")
                    .font(.largeTitle.weight(.bold))
                Text("Citas y amistades.\nTu passkey es tu cuenta.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Crear cuenta con passkey") {
                    Task { await model?.register() }
                }
                .buttonStyle(.glassProminent)

                Button("Entrar con mi passkey") {
                    Task { await model?.signIn() }
                }
                .buttonStyle(.glass)

                #if DEBUG
                // Las passkeys necesitan un dominio asociado firmado con una
                // cuenta de Apple Developer. Mientras no la haya, esta puerta
                // trasera deja seguir construyendo el resto de la app.
                // El handle va en el boton: en UAT se lanzan dos simuladores con
                // cuentas distintas y hay que saber cual es cual de un vistazo.
                Button("Entrar sin passkey · \(AuthViewModel.developmentHandle)") {
                    Task { await model?.signInForDevelopment() }
                }
                .buttonStyle(.glass)
                .tint(.orange)
                #endif
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(model?.isWorking ?? true)

            Label("Passkey · Face ID", systemImage: "faceid")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay {
            if model?.isWorking == true { ProgressView() }
        }
        .alert("No se pudo continuar",
               isPresented: Binding(get: { model?.errorMessage != nil },
                                    set: { if !$0 { model?.errorMessage = nil } }),
               presenting: model?.errorMessage) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .task {
            if model == nil { model = AuthViewModel(session: session) }
        }
    }
}
