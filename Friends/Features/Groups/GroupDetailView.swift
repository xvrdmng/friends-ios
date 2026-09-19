import SwiftUI

/// Ficha de un grupo: quien esta dentro, como entrar y su mazo propio.
struct GroupDetailView: View {
    let group: FriendGroup
    var onJoined: (FriendGroup) -> Void = { _ in }
    var onLeft: (FriendGroup) -> Void = { _ in }
    var onClose: () -> Void = {}

    @State private var model: GroupDetailViewModel
    @State private var showDeck = false
    @State private var confirmLeave = false
    @State private var askInviteCode = false
    @State private var inviteCode = ""
    @State private var report: ReportTarget?
    @State private var kickTarget: Person?

    init(group: FriendGroup,
         onJoined: @escaping (FriendGroup) -> Void = { _ in },
         onLeft: @escaping (FriendGroup) -> Void = { _ in },
         onClose: @escaping () -> Void = {}) {
        self.group = group
        self.onJoined = onJoined
        self.onLeft = onLeft
        self.onClose = onClose
        _model = State(initialValue: GroupDetailViewModel(group: group))
    }

    private var current: FriendGroup { model.group }

    var body: some View {
        NavigationStack {
            List {
                if let url = current.coverUrl {
                    Section {
                        RemoteImage(url: url)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(.init())
                    }
                }

                Section {
                    header
                    if current.status == "under_review" { reviewNotice }
                    if let description = current.description, !description.isEmpty {
                        Text(description)
                    }
                    if !current.interests.isEmpty { interestChips }
                }

                Section { actions }

                if current.isMember { membersSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(current.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Volver", systemImage: "chevron.left", action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let code = current.inviteCode, current.canModerate {
                            Button("Copiar código de invitación", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = code
                            }
                        }
                        Button("Reportar grupo", systemImage: "flag") {
                            report = ReportTarget(kind: .group, id: current.id, userID: nil, displayName: current.name)
                        }
                        if current.isMember && !current.isOwner {
                            Button("Salir del grupo", systemImage: "rectangle.portrait.and.arrow.right",
                                   role: .destructive) { confirmLeave = true }
                        }
                    } label: {
                        Label("Más opciones", systemImage: "ellipsis")
                    }
                }
            }
        }
        .errorAlert(Binding(get: { model.error }, set: { model.error = $0 }))
        .task { await model.load() }
        .fullScreenCover(isPresented: $showDeck) {
            DeckView(context: .group, groupSlug: current.slug, groupID: current.id,
                     groupName: current.name) { showDeck = false }
        }
        .sheet(item: $report) { target in ReportSheet(target: target) { _ in onClose() } }
        .alert("Grupo privado", isPresented: $askInviteCode) {
            TextField("Código de invitación", text: $inviteCode)
            Button("Entrar") { Task { await join(code: inviteCode) } }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Pide el código a quien te invitó.") }
        .confirmationDialog("¿Salir de \(current.name)?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Salir del grupo", role: .destructive) {
                Task { if await model.leave() { onLeft(current); onClose() } }
            }
        } message: { Text("Perderás los matches del grupo que aún no tengan conversación.") }
        .confirmationDialog("¿Expulsar a \(kickTarget?.displayName ?? "")?",
                            isPresented: Binding(get: { kickTarget != nil },
                                                 set: { if !$0 { kickTarget = nil } }),
                            titleVisibility: .visible) {
            Button("Expulsar", role: .destructive) {
                if let person = kickTarget { Task { await model.kick(person) } }
            }
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        ChipFlow {
            if let category = Labels.categories[current.category] {
                Tag(text: "\(category.emoji) \(category.name)", tint: Color.accentColor)
            }
            Tag(text: "\(current.membersCount) miembros")
            if let distance = Labels.distance(current.distanceKm) { Tag(text: distance) }
            if current.isPrivate { Tag(text: "Privado") }
        }
    }

    private var reviewNotice: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grupo en revisión").font(.headline)
                Text("Alguien lo reportó. Mientras lo revisamos no aparece en el descubrimiento.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    private var interestChips: some View {
        ChipFlow {
            ForEach(current.interests) { interest in
                Tag(text: "\(interest.emoji ?? "") \(interest.name)")
            }
        }
    }

    // MARK: - Acciones

    @ViewBuilder
    private var actions: some View {
        if current.isMember {
            Button("Ver el mazo del grupo", systemImage: "rectangle.stack") { showDeck = true }
                .frame(maxWidth: .infinity)
        } else {
            Button(model.isWorking ? "Entrando…" : "Unirme al grupo") {
                if current.isPrivate { askInviteCode = true } else { Task { await join(code: nil) } }
            }
            .frame(maxWidth: .infinity)
            .disabled(model.isWorking)
        }
    }

    private func join(code: String?) async {
        if let joined = await model.join(inviteCode: code?.isEmpty == true ? nil : code) {
            onJoined(joined)
        }
    }

    // MARK: - Miembros

    private var membersSection: some View {
        Section("Miembros") {
            ForEach(model.members) { person in
                HStack(spacing: 12) {
                    AvatarView(url: person.thumbUrl, name: person.displayName, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.displayName).font(.headline).lineLimit(1)
                        if let age = person.age {
                            Text("\(age) años").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    if person.role == "owner" { Tag(text: "Dueño", tint: Color.accentColor) }
                    else if person.role == "moderator" { Tag(text: "Mod", tint: Color.accentColor) }
                }
                .swipeActions(edge: .trailing) {
                    if current.canModerate, person.role != "owner", person.role != "moderator" {
                        Button("Expulsar", systemImage: "person.fill.xmark", role: .destructive) {
                            kickTarget = person
                        }
                    }
                }
            }
        }
    }
}
