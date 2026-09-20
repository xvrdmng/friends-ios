import SwiftUI

/// Abre una conversacion resolviendo primero quien soy.
///
/// El chat necesita mi id para saber que mensajes son mios. Antes las pantallas
/// hacian `if let myID = account.userID { ChatView(...) }` dentro del
/// `fullScreenCover`: si el id todavia no estaba resuelto —o `/me` habia
/// fallado— se presentaba una vista VACIA, sin nada que tocar y sin boton de
/// volver, y habia que matar la app. Aqui siempre hay salida.
struct ChatLauncher: View {
    let match: Match
    var onClose: (_ unmatched: Bool) -> Void

    @State private var myID: String?
    @State private var failed = false

    var body: some View {
        Group {
            if let myID {
                ChatView(match: match, myID: myID, onClose: onClose)
            } else {
                waiting
            }
        }
        .task {
            myID = await AccountStore.shared.requireUserID()
            failed = myID == nil
        }
    }

    private var waiting: some View {
        NavigationStack {
            Group {
                if failed {
                    ContentUnavailableView {
                        Label("No se pudo abrir el chat", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("No hemos podido cargar tu cuenta. Revisa tu conexión.")
                    } actions: {
                        Button("Reintentar") {
                            failed = false
                            Task {
                                myID = await AccountStore.shared.requireUserID()
                                failed = myID == nil
                            }
                        }
                        .buttonStyle(.glassProminent)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(match.other.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Volver", systemImage: "chevron.left") { onClose(false) }
                }
            }
        }
    }
}
