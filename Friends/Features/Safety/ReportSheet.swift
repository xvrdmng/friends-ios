import SwiftUI

/// Que se esta reportando. El servidor deduce a quien pertenece (`target_user`).
struct ReportTarget: Identifiable, Equatable {
    enum Kind: String { case user = "User", message = "Message", group = "Group", photo = "Photo" }

    let kind: Kind
    let id: String
    /// Persona a la que se podria bloquear en el mismo gesto (nil si es un grupo).
    let userID: String?
    let displayName: String
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam, fake_profile, inappropriate_content, harassment, underage, scam, hate, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam:                  "Spam o publicidad"
        case .fake_profile:          "Perfil falso"
        case .inappropriate_content: "Contenido inapropiado"
        case .harassment:            "Acoso o insultos"
        case .underage:              "Parece menor de edad"
        case .scam:                  "Estafa"
        case .hate:                  "Discurso de odio"
        case .other:                 "Otro motivo"
        }
    }
}

/// Hoja de reporte. Se abre desde el mazo, el chat y los grupos.
struct ReportSheet: View {
    let target: ReportTarget
    var api: any APIService = APIClient.shared
    var onFinished: (_ didBlock: Bool) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var alsoBlock = true
    @State private var isSending = false
    @State private var error: AlertMessage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ReportReason.allCases) { item in
                        Button { reason = item } label: {
                            LabeledContent {
                                if reason == item {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            } label: {
                                Text(item.label).foregroundStyle(Color.primary)
                            }
                        }
                        .accessibilityAddTraits(reason == item ? [.isSelected] : [])
                    }
                } header: {
                    Text("Motivo")
                } footer: {
                    Text("Revisamos cada reporte en menos de 24 horas. La otra persona no sabrá que fuiste tú.")
                }

                Section("Cuéntanos más (opcional)") {
                    TextField("Detalles", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if target.userID != nil {
                    Section {
                        Toggle("Bloquear también a \(target.displayName)", isOn: $alsoBlock)
                    }
                }
            }
            .navigationTitle("Reportar a \(target.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") { Task { await send() } }
                        .disabled(reason == nil || isSending)
                }
            }
            .errorAlert($error)
            .disabled(isSending)
        }
    }

    private func send() async {
        guard let reason, !isSending else { return }
        isSending = true
        defer { isSending = false }
        let block = alsoBlock && target.userID != nil
        do {
            try await api.send(.report, body: ReportRequest(
                reportableType: target.kind.rawValue, reportableId: target.id, reason: reason.rawValue,
                note: note.isEmpty ? nil : note, block: block
            ))
            onFinished(block)
            dismiss()
        } catch {
            self.error = AlertMessage("No se pudo enviar el reporte", message: "Inténtalo de nuevo.")
        }
    }
}

/// Bloquear a una persona. Desaparece de mazos, grupos y chat, y sus matches se
/// deshacen.
enum SafetyActions {
    static func block(userID: String, api: any APIService = APIClient.shared) async -> Bool {
        do { try await api.send(.block, body: BlockRequest(userId: userID)); return true }
        catch { return false }
    }
}

/// Lista de personas bloqueadas, para poder desbloquear.
struct BlockedUsersView: View {
    var api: any APIService = APIClient.shared
    @State private var people: [Person] = []
    @State private var isLoading = true
    @State private var error: AlertMessage?
    @State private var restored: String?
    var onMatchRestored: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if people.isEmpty {
                ContentUnavailableView {
                    Label("No has bloqueado a nadie", systemImage: "hand.raised")
                } description: {
                    Text("Quien bloquees dejará de verte y de escribirte.")
                }
            } else {
                List {
                    ForEach(people) { person in
                        HStack(spacing: 12) {
                            AvatarView(url: person.thumbUrl, name: person.displayName, size: 44)
                            Text(person.displayName).font(.headline)
                            Spacer()
                            // Boton a la vista: escondido solo tras el swipe no
                            // lo encuentra nadie, y desbloquear tiene que ser
                            // tan facil como bloquear.
                            Button("Desbloquear") { Task { await unblock(person) } }
                                .buttonStyle(.bordered)
                                .font(.subheadline)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Desbloquear", systemImage: "hand.raised.slash") {
                                Task { await unblock(person) }
                            }
                            .tint(Color.accentColor)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Bloqueados")
        .navigationBarTitleDisplayMode(.inline)
        // Sin esto la pantalla no tenia salida: se abre en una hoja y solo se
        // podia cerrar arrastrandola, cosa que no adivina nadie.
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
        }
        .errorAlert($error)
        .alert("Volvió tu match", isPresented: Binding(get: { restored != nil },
                                                       set: { if !$0 { restored = nil } }),
               presenting: restored) { _ in
            Button("Vale", role: .cancel) {}
        } message: { name in
            Text("\(name) vuelve a estar en tus chats, con la conversación como la dejasteis.")
        }
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        if let response: BlocksResponse = try? await api.send(.blocks) { people = response.blocks }
    }

    private func unblock(_ person: Person) async {
        do {
            let response: UnblockResponse = try await api.send(.unblock(userID: person.userId))
            people.removeAll { $0.id == person.id }
            if !response.restoredMatches.isEmpty {
                restored = person.displayName
                onMatchRestored()
            }
        } catch {
            self.error = AlertMessage("No se pudo desbloquear")
        }
    }
}
