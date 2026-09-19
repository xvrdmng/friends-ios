import SwiftUI

/// Grupos por categoría e intereses. Dentro de cada grupo hay su propio mazo.
struct GroupsView: View {
    @State private var model = GroupsViewModel()
    @State private var open: FriendGroup?
    @State private var showCreate = false

    var body: some View {
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchField
                    categoryRow
                    content
                }
                .padding(.horizontal, 22).padding(.trailing, 4).padding(.bottom, 110)
            }
            .drivesTabBar()
            .refreshable { await model.load() }
        }
        .toast(Binding(get: { model.toast }, set: { model.toast = $0 }))
        .task { await model.load() }
        .fullScreenCover(item: $open) { group in
            GroupDetailView(group: group,
                            onJoined: { model.didJoin($0) },
                            onLeft: { model.didLeave($0) },
                            onClose: { open = nil })
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupView { created in
                showCreate = false
                model.didJoin(created)
                open = created
            }
        }
    }

    private var header: some View {
        HStack {
            Text("GROUPS").font(.lazyTitle).foregroundStyle(Color.lazyBlack)
            Spacer()
            Button { showCreate = true } label: {
                Image(systemName: "plus").font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 46, height: 46)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 3))
            }
            .accessibilityLabel("Crear grupo")
        }
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .bold))
            TextField("Buscar grupos", text: Bindable(model).query)
                .font(.lazyBody).autocorrectionDisabled()
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(.secondary).accessibilityLabel("Borrar búsqueda")
            }
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .lazyCard(cornerRadius: 18).stickerPadding()
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ChoiceChip(label: "Todos", selectedColor: .lazyMint, isSelected: model.category == nil) {
                    model.category = nil
                }
                ForEach(Array(Labels.categories.keys).sorted(), id: \.self) { key in
                    let item = Labels.categories[key]!
                    ChoiceChip(label: item.name, emoji: item.emoji, selectedColor: .lazyMint,
                               isSelected: model.category == key) {
                        model.category = model.category == key ? nil : key
                    }
                }
            }
            .padding(.vertical, 4).padding(.trailing, 6)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
        case .failed:
            StateCard(emoji: "📡", title: "No se pudieron cargar los grupos", message: "Revisa tu conexión.",
                      actionTitle: "Reintentar") { Task { await model.load() } }
        case .ready:
            if !model.mine.isEmpty {
                Text("TUS GRUPOS").font(.lazyMono).foregroundStyle(.secondary)
                ForEach(model.mine) { group in card(group) }
            }
            Text(model.query.isEmpty ? "DESCUBRE" : "RESULTADOS").font(.lazyMono).foregroundStyle(.secondary)
            if model.discover.isEmpty {
                StateCard(emoji: "🔍",
                          title: model.query.isEmpty ? "No hay grupos por aquí" : "Sin resultados",
                          message: "Crea el primero y que se sumen los demás.",
                          color: .lazyMint, actionTitle: "Crear grupo") { showCreate = true }
            } else {
                ForEach(model.discover) { group in card(group) }
            }
        }
    }

    private func card(_ group: FriendGroup) -> some View {
        Button { open = group } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let cover = group.coverUrl {
                    RemoteImage(url: cover).frame(height: 130).frame(maxWidth: .infinity).clipped()
                    Divider().overlay(Color.lazyBlack).frame(height: 3)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(Labels.categories[group.category]?.emoji ?? "👥").font(.system(size: 22))
                        Text(group.name).font(.lazySubhead).lineLimit(1)
                        Spacer(minLength: 4)
                        if group.isPrivate { Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)) }
                    }
                    if let description = group.description, !description.isEmpty {
                        Text(description).font(.lazyCaption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        Tag(text: "\(group.membersCount) miembros", color: .lazyYellow)
                        if let distance = Labels.distance(group.distanceKm) { Tag(text: distance) }
                        if group.isMember { Tag(text: group.isOwner ? "Tuyo" : "Miembro", color: .lazyMint) }
                    }
                }
                .padding(14)
            }
            .foregroundStyle(Color.lazyBlack)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lazyCard().stickerPadding()
        }
        .buttonStyle(.plain)
    }
}
