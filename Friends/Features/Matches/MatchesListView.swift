import SwiftUI

@MainActor
@Observable
final class MatchesListViewModel {
    enum Phase { case loading, ready, failed }

    private(set) var matches: [Match] = []
    private(set) var phase: Phase = .loading
    private let api: any APIService

    init(api: any APIService = APIClient.shared) { self.api = api }

    /// Nuevos: aun sin mensajes. El resto, ordenado por el ultimo mensaje.
    var newMatches: [Match] { matches.filter { $0.lastMessage == nil } }
    var conversations: [Match] {
        matches.filter { $0.lastMessage != nil }
            .sorted { ($0.lastMessage?.createdAt ?? .distantPast) > ($1.lastMessage?.createdAt ?? .distantPast) }
    }
    var totalUnread: Int { matches.reduce(0) { $0 + $1.unreadCount } }

    func load() async {
        do {
            let response: MatchesResponse = try await api.send(.matches)
            matches = response.matches
            phase = .ready
        } catch {
            if matches.isEmpty { phase = .failed }
        }
    }

    func remove(id: String) { matches.removeAll { $0.id == id } }
}

/// Matches y sus chats. Un match nace con su conversacion ya creada.
struct MatchesListView: View {
    @State private var model = MatchesListViewModel()
    @State private var account = AccountStore.shared
    @State private var open: Match?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Chats")
                .refreshable { await model.load() }
        }
        .task { await model.load(); await account.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.load() } } }
        .fullScreenCover(item: $open, onDismiss: { Task { await model.load() } }) { match in
            if let myID = account.userID {
                ChatView(match: match, myID: myID) { unmatched in
                    if unmatched { model.remove(id: match.id) }
                    open = nil
                }
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
                Label("No se pudieron cargar tus chats", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Revisa tu conexión.")
            } actions: {
                Button("Reintentar") { Task { await model.load() } }
                    .buttonStyle(.glassProminent)
            }

        case .ready where model.matches.isEmpty:
            ContentUnavailableView {
                Label("Aún no tienes matches", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Cuando a alguien le guste que te guste, aparecerá aquí.")
            }

        case .ready:
            List {
                if !model.newMatches.isEmpty {
                    Section("Nuevos matches") { newMatchesRow }
                }
                if !model.conversations.isEmpty {
                    Section("Mensajes") {
                        ForEach(model.conversations) { match in row(match) }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var newMatchesRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(model.newMatches) { match in
                    Button { open = match } label: {
                        VStack(spacing: 6) {
                            AvatarView(url: match.other.thumbUrl, name: match.other.displayName, size: 64)
                            Text(match.other.displayName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nuevo match con \(match.other.displayName)")
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 0))
    }

    private func row(_ match: Match) -> some View {
        Button { open = match } label: {
            HStack(spacing: 12) {
                AvatarView(url: match.other.thumbUrl, name: match.other.displayName)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(match.other.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        if let group = match.group {
                            Tag(text: group.name, tint: Color.accentColor)
                        }
                    }
                    Text(preview(match.lastMessage))
                        .font(.subheadline)
                        .foregroundStyle(match.unreadCount > 0 ? Color.primary : .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 6) {
                    if let date = match.lastMessage?.createdAt {
                        Text(date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if match.unreadCount > 0 {
                        Text(match.unreadCount.formatted())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.accentColor, in: .capsule)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: match))
    }

    private func accessibilityLabel(for match: Match) -> String {
        var parts = [match.other.displayName]
        if match.unreadCount > 0 { parts.append("\(match.unreadCount) sin leer") }
        parts.append(preview(match.lastMessage))
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func preview(_ message: ChatMessage?) -> String {
        guard let message else { return "" }
        let text = message.kind == "image" ? "Foto" : (message.body ?? "")
        return message.mine ? "Tú: \(text)" : text
    }
}
