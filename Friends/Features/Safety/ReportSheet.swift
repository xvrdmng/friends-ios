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
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DoodleBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Reportar a \(target.displayName)")
                            .font(.lazyHeading).foregroundStyle(Color.lazyBlack)
                        Text("Revisamos cada reporte en menos de 24 horas. La otra persona no sabrá que fuiste tú.")
                            .font(.lazyCaption).foregroundStyle(.secondary)

                        ChipFlow {
                            ForEach(ReportReason.allCases) { item in
                                ChoiceChip(label: item.label, selectedColor: .lazyYellow, isSelected: reason == item) { reason = item }
                            }
                        }

                        TextField("Cuéntanos más (opcional)", text: $note, axis: .vertical)
                            .font(.lazyBody).lineLimit(3...6)
                            .padding(14).lazyCard(cornerRadius: 14).stickerPadding()

                        if target.userID != nil {
                            Toggle(isOn: $alsoBlock) {
                                Text("Bloquear también a \(target.displayName)").font(.lazySubhead)
                            }
                            .tint(Color.lazyRose)
                            .foregroundStyle(Color.lazyBlack)
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.lazyCaption)
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .lazyCard(backgroundColor: .lazyNotice, cornerRadius: 12, offset: 3).stickerPadding()
                        }

                        Button("Enviar reporte") { Task { await send() } }
                            .buttonStyle(LazyButtonStyle(background: .lazyRose, foreground: .lazyBlack, fillsWidth: true))
                            .disabled(reason == nil || isSending)
                            .opacity(reason == nil ? 0.5 : 1)
                            .stickerPadding()
                    }
                    .padding(22)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
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
            errorMessage = "No se pudo enviar el reporte. Inténtalo de nuevo."
        }
    }
}

/// Bloquear a una persona. Desaparece de mazos, grupos y chat, y sus matches se deshacen.
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
    @State private var toast: Toast?

    var body: some View {
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if isLoading { ProgressView().padding(.top, 40) }
                    else if people.isEmpty {
                        StateCard(emoji: "🕊️", title: "No has bloqueado a nadie").padding(.top, 20)
                    } else {
                        ForEach(people) { person in
                            HStack(spacing: 14) {
                                AvatarView(url: person.thumbUrl, name: person.displayName)
                                Text(person.displayName).font(.lazySubhead)
                                Spacer()
                                Button("Desbloquear") { Task { await unblock(person) } }
                                    .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack))
                                    .scaleEffect(0.75)
                            }
                            .foregroundStyle(Color.lazyBlack)
                            .padding(12).lazyCard().stickerPadding()
                        }
                    }
                }
                .padding(22)
            }
        }
        .navigationTitle("Bloqueados")
        .toast($toast)
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        if let response: BlocksResponse = try? await api.send(.blocks) { people = response.blocks }
    }

    private func unblock(_ person: Person) async {
        do {
            try await api.send(.unblock(userID: person.userId))
            people.removeAll { $0.id == person.id }
            toast = Toast(text: "\(person.displayName) desbloqueado")
        } catch {
            toast = Toast(text: "No se pudo desbloquear", isError: true)
        }
    }
}
