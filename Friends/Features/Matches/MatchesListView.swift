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
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("CHATS").font(.lazyTitle).foregroundStyle(Color.lazyBlack).padding(.top, 8)
                    content
                }
                .padding(.horizontal, 22).padding(.trailing, 4).padding(.bottom, 110)
            }
            .drivesTabBar()
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
            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
        case .failed:
            StateCard(emoji: "📡", title: "No se pudieron cargar tus chats", message: "Revisa tu conexión.",
                      actionTitle: "Reintentar") { Task { await model.load() } }
        case .ready where model.matches.isEmpty:
            StateCard(emoji: "💬", title: "Aún no tienes matches",
                      message: "Cuando a alguien le guste que te guste, aparecerá aquí.", color: .lazyYellow)
        case .ready:
            if !model.newMatches.isEmpty { newMatchesRow }
            if !model.conversations.isEmpty {
                Text("MENSAJES").font(.lazyMono).foregroundStyle(.secondary)
                ForEach(model.conversations) { match in row(match) }
            }
        }
    }

    private var newMatchesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NUEVOS MATCHES").font(.lazyMono).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(model.newMatches) { match in
                        Button { open = match } label: {
                            VStack(spacing: 6) {
                                AvatarView(url: match.other.thumbUrl, name: match.other.displayName, size: 68)
                                Text(match.other.displayName).font(.lazyCaption).lineLimit(1)
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(.plain).foregroundStyle(Color.lazyBlack)
                        .accessibilityLabel("Nuevo match con \(match.other.displayName)")
                    }
                }
                .padding(.vertical, 4).padding(.trailing, 6)
            }
        }
    }

    private func row(_ match: Match) -> some View {
        Button { open = match } label: {
            HStack(spacing: 14) {
                AvatarView(url: match.other.thumbUrl, name: match.other.displayName)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(match.other.displayName).font(.lazySubhead).lineLimit(1)
                        if let group = match.group { Tag(text: group.name, color: .lazyMint) }
                    }
                    Text(preview(match.lastMessage)).font(.lazyCaption)
                        .foregroundStyle(match.unreadCount > 0 ? Color.lazyBlack : .secondary)
                        .fontWeight(match.unreadCount > 0 ? .bold : .regular).lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 6) {
                    if let date = match.lastMessage?.createdAt {
                        Text(date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                            .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    if match.unreadCount > 0 {
                        Text("\(match.unreadCount)").font(.system(size: 13, weight: .black))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.lazyRose, in: Capsule()).overlay(Capsule().stroke(Color.lazyBlack, lineWidth: 2))
                    }
                }
            }
            .foregroundStyle(Color.lazyBlack)
            .padding(12).lazyCard().stickerPadding()
        }
        .buttonStyle(.plain)
    }

    private func preview(_ message: ChatMessage?) -> String {
        guard let message else { return "" }
        let text = message.kind == "image" ? "📷 Foto" : (message.body ?? "")
        return message.mine ? "Tú: \(text)" : text
    }
}
