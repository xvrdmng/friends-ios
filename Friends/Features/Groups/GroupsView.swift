import SwiftUI

/// Grupos por categoría e intereses. Dentro de cada grupo hay su propio mazo.
struct GroupsView: View {
    @State private var model = GroupsViewModel()
    @State private var open: FriendGroup?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Grupos")
                .searchable(text: Bindable(model).query, prompt: "Buscar grupos")
                .refreshable { await model.load() }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Crear grupo", systemImage: "plus") { showCreate = true }
                    }
                }
        }
        .errorAlert(Binding(get: { model.error }, set: { model.error = $0 }))
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

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            ContentUnavailableView {
                Label("No se pudieron cargar los grupos", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Revisa tu conexión.")
            } actions: {
                Button("Reintentar") { Task { await model.load() } }
                    .buttonStyle(.glassProminent)
            }

        case .ready:
            List {
                Section { categoryRow }
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 0))

                if !model.visibleMine.isEmpty {
                    Section("Tus grupos") {
                        ForEach(model.visibleMine) { group in row(group) }
                    }
                }

                Section(model.query.isEmpty ? "Descubre" : "Resultados") {
                    if model.discover.isEmpty { discoverEmpty } else {
                        ForEach(model.discover) { group in row(group) }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var discoverEmpty: some View {
        if model.query.isEmpty {
            ContentUnavailableView {
                Label("No hay grupos por aquí", systemImage: "person.3")
            } description: {
                Text("Crea el primero y que se sumen los demás.")
            } actions: {
                Button("Crear grupo") { showCreate = true }
                    .buttonStyle(.glassProminent)
            }
            .listRowBackground(Color.clear)
        } else if model.hasNoResults {
            ContentUnavailableView {
                Label("Sin resultados", systemImage: "magnifyingglass")
            } description: {
                Text("No hay ningún grupo que se llame «\(model.query)».")
            } actions: {
                Button("Crear «\(model.query)»") { showCreate = true }
                    .buttonStyle(.glassProminent)
            }
            .listRowBackground(Color.clear)
        } else {
            // Tu grupo si esta, arriba: decir "sin resultados" aqui seria mentir.
            Text("Nada nuevo con ese nombre. Los tuyos salen arriba.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ChoiceChip(label: "Todos", isSelected: model.category == nil) {
                    model.category = nil
                }
                ForEach(Array(Labels.categories.keys).sorted(), id: \.self) { key in
                    let item = Labels.categories[key]!
                    ChoiceChip(label: item.name, emoji: item.emoji, isSelected: model.category == key) {
                        model.category = model.category == key ? nil : key
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ group: FriendGroup) -> some View {
        Button { open = group } label: {
            HStack(spacing: 12) {
                cover(group)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.headline)
                            .lineLimit(1)
                        if group.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Grupo privado")
                        }
                    }
                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Tag(text: "\(group.membersCount) miembros")
                        if let distance = Labels.distance(group.distanceKm) { Tag(text: distance) }
                        if group.isMember {
                            Tag(text: group.isOwner ? "Tuyo" : "Miembro", tint: Color.accentColor)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cover(_ group: FriendGroup) -> some View {
        if let url = group.coverUrl {
            RemoteImage(url: url)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
        } else {
            Text(Labels.categories[group.category]?.emoji ?? "👥")
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemFill), in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}
