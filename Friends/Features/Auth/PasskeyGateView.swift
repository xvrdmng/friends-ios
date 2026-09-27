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

            Button {
                Task { await model?.continueWithPasskey() }
            } label: {
                Label("Continuar con Passkey", systemImage: "person.badge.key.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color(.label), in: .rect(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
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
            #if DEBUG
            // uat.sh lanza cada simulador con su DEV_HANDLE: entran solos.
            if AuthViewModel.explicitDevelopmentHandle != nil { await model?.signInForDevelopment() }
            #endif
        }
    }
}
