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
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cover
                    title
                    if current.status == "under_review" { reviewNotice }
                    if let description = current.description, !description.isEmpty {
                        Text(description).font(.lazyBody).foregroundStyle(Color.lazyBlack)
                    }
                    if !current.interests.isEmpty { interestChips }
                    actions
                    if current.isMember { membersSection }
                }
                .padding(.horizontal, 22).padding(.trailing, 4).padding(.bottom, 40)
            }
            .safeAreaInset(edge: .top) { toolbar }
        }
        .toast(Binding(get: { model.toast }, set: { model.toast = $0 }))
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
                            isPresented: Binding(get: { kickTarget != nil }, set: { if !$0 { kickTarget = nil } }),
                            titleVisibility: .visible) {
            Button("Expulsar", role: .destructive) {
                if let person = kickTarget { Task { await model.kick(person) } }
            }
        }
    }

    // MARK: - Cabecera

    private var toolbar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 44, height: 44).glassEffect(.regular, in: .circle)
            }
            .accessibilityLabel("Volver")
            Spacer()
            Menu {
                if let code = current.inviteCode, current.canModerate {
                    Button("Copiar código de invitación", systemImage: "doc.on.doc") { UIPasteboard.general.string = code }
                }
                Button("Reportar grupo", systemImage: "flag") {
                    report = ReportTarget(kind: .group, id: current.id, userID: nil, displayName: current.name)
                }
                if current.isMember && !current.isOwner {
                    Button("Salir del grupo", systemImage: "arrow.right.square", role: .destructive) { confirmLeave = true }
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 44, height: 44).glassEffect(.regular, in: .circle)
            }
            .accessibilityLabel("Más opciones")
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
    }

    @ViewBuilder
    private var cover: some View {
        if let url = current.coverUrl {
            RemoteImage(url: url).frame(height: 180).frame(maxWidth: .infinity)
                .clipped().lazyCard(cornerRadius: 20).stickerPadding()
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(current.name).font(.lazyHeading).foregroundStyle(Color.lazyBlack)
            HStack(spacing: 8) {
                if let category = Labels.categories[current.category] {
                    Tag(text: "\(category.emoji) \(category.name)", color: .lazyMint)
                }
                Tag(text: "\(current.membersCount) miembros", color: .lazyYellow)
                if let distance = Labels.distance(current.distanceKm) { Tag(text: distance) }
                if current.isPrivate { Tag(text: "🔒 Privado") }
            }
        }
    }

    private var reviewNotice: some View {
        StateCard(emoji: "⚠️", title: "Grupo en revisión",
                  message: "Alguien lo reportó. Mientras lo revisamos no aparece en el descubrimiento.",
                  color: .lazyNotice)
    }

    private var interestChips: some View {
        ChipFlow(spacing: 8) {
            ForEach(current.interests) { interest in
                Text("\(interest.emoji ?? "") \(interest.name)")
                    .font(.lazyCaption).foregroundStyle(Color.lazyBlack)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .lazyCard(cornerRadius: 14, offset: 2).padding(.trailing, 2).padding(.bottom, 2)
            }
        }
    }

    // MARK: - Acciones

    @ViewBuilder
    private var actions: some View {
        if current.isMember {
            Button("Ver el mazo del grupo") { showDeck = true }
                .buttonStyle(LazyButtonStyle(background: .lazyRose, foreground: .lazyBlack, fillsWidth: true))
        } else {
            Button(model.isWorking ? "Entrando…" : "Unirme al grupo") {
                if current.isPrivate { askInviteCode = true } else { Task { await join(code: nil) } }
            }
            .buttonStyle(LazyButtonStyle(background: .lazyMint, foreground: .lazyBlack, fillsWidth: true))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("MIEMBROS").font(.lazyMono).foregroundStyle(.secondary)
            ForEach(model.members) { person in
                HStack(spacing: 14) {
                    AvatarView(url: person.thumbUrl, name: person.displayName, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.displayName).font(.lazySubhead).lineLimit(1)
                        if let age = person.age { Text("\(age) años").font(.lazyMono).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 4)
                    if person.role == "owner" { Tag(text: "Dueño", color: .lazyYellow) }
                    else if person.role == "moderator" { Tag(text: "Mod", color: .lazyMint) }
                    else if current.canModerate {
                        Button { kickTarget = person } label: {
                            Image(systemName: "person.fill.xmark").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color.lazyRed)
                        .accessibilityLabel("Expulsar a \(person.displayName)")
                    }
                }
                .foregroundStyle(Color.lazyBlack)
                .padding(12).lazyCard().stickerPadding()
            }
        }
    }
}
