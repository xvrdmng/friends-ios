import SwiftUI

/// Los likes que te han dado, separados por lo que buscaba cada persona:
/// una cita, una amistad o practicar un idioma. Sin premium solo se ve cuantos.
struct LikesView: View {
    @State private var model = LikesViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Modo", selection: Bindable(model).context) {
                    ForEach(LikesViewModel.kinds, id: \.self) { kind in
                        Text("\(kind.title)\(model.badge(kind))").tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top], 16)
                content
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Likes")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.load() }
        }
        .tint(model.context.tint)
        .task(id: model.context) { await model.load() }
        .errorAlert(Binding(get: { model.error }, set: { model.error = $0 }))
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .likesReceived) }
    }

    @ViewBuilder
    private var content: some View {
        if let response = model.response {
            if response.count == 0 {
                ContentUnavailableView("Aún no hay likes", systemImage: model.context.symbol,
                                       description: Text("Cuando alguien te dé like en \(model.context.title.lowercased()) lo verás aquí."))
            } else if let people = response.people {
                List(people) { person in
                    HStack(spacing: 12) {
                        AvatarView(url: person.thumbUrl, name: person.displayName, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName).font(.headline)
                            if let age = person.age { Text("\(age) años").font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: model.context.symbol).foregroundStyle(model.context.tint)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView {
                    Label("\(response.count) \(response.count == 1 ? "persona" : "personas") te dio like",
                          systemImage: model.context.symbol)
                } description: {
                    Text("Hazte premium para ver quién es.")
                } actions: {
                    Button("Ver quién") { showPaywall = true }.buttonStyle(.glassProminent)
                }
            }
        } else if model.failed {
            ContentUnavailableView {
                Label("No pudimos cargar tus likes", systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Reintentar") { Task { await model.load() } }.buttonStyle(.glassProminent)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

@MainActor
@Observable
final class LikesViewModel {
    static let kinds: [DeckContext] = [.dating, .friendship, .language]

    var context: DeckContext = .dating
    private(set) var response: ReceivedLikesResponse?
    private(set) var counts: [String: Int] = [:]
    private(set) var failed = false
    var error: AlertMessage?

    private let api: any APIService
    init(api: any APIService = APIClient.shared) { self.api = api }

    /// " (3)" junto al nombre de cada modo, para ver de un vistazo donde hay likes.
    func badge(_ kind: DeckContext) -> String {
        let n = counts[kind.rawValue] ?? 0
        return n > 0 ? " (\(n))" : ""
    }

    func load() async {
        let asked = context
        response = nil
        failed = false
        do {
            let result: ReceivedLikesResponse = try await api.send(.likesReceived(context: asked))
            guard asked == context else { return }
            response = result
            if let counts = result.counts { self.counts = counts }
        } catch {
            if asked == context { failed = true }
        }
    }
}
