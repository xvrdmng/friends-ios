import Foundation
import Observation

/// Estado de una conversacion.
///
/// - Los mensajes propios aparecen al instante (optimistas) con un `client_id`; si la
///   red falla se pueden reintentar SIN duplicarse, porque el servidor es idempotente
///   por `client_id`.
/// - El eco que llega por el canal se reconcilia con el mensaje local (mismo id o
///   mismo client_id) en vez de anadirse otra vez.
@MainActor
@Observable
final class ChatViewModel {
    enum SendState: Equatable { case sending, failed }

    private(set) var messages: [ChatMessage] = []      // del mas antiguo al mas nuevo
    private(set) var sendStates: [String: SendState] = [:]   // por client_id
    private(set) var hasMore = false
    private(set) var isLoading = true
    private(set) var isLoadingOlder = false
    private(set) var otherIsTyping = false
    private(set) var isClosed = false                   // match deshecho o bloqueo
    var draft = "" { didSet { if !draft.isEmpty && draft != oldValue { notifyTyping() } } }
    var errorMessage: String?

    let match: Match
    private let myID: String
    private let api: any APIService
    private let cable: CableClient
    private var lastTypingSent = Date.distantPast
    private var typingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?

    init(match: Match, myID: String, api: any APIService = APIClient.shared, cable: CableClient = .shared) {
        self.match = match
        self.myID = myID
        self.api = api
        self.cable = cable
    }

    // MARK: - Ciclo de vida

    func start() async {
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            guard let self else { return }
            for await event in cable.events(matchID: match.id) { handle(event) }
        }
        await loadLatest()
        await markRead()
    }

    func stop() {
        listenTask?.cancel()
        typingTask?.cancel()
    }

    /// Al volver a primer plano: se pide lo que pudo llegar mientras el socket estaba caido.
    func refresh() async {
        cable.reconnectIfNeeded()
        await loadLatest()
        await markRead()
    }

    private func loadLatest() async {
        do {
            let response: MessagesResponse = try await api.send(.messages(matchID: match.id, before: nil))
            let firstLoad = messages.isEmpty
            merge(response.messages.reversed())
            // Solo la primera carga sabe si hay paginas anteriores; un refresco no la pisa.
            if firstLoad { hasMore = response.hasMore }
            isLoading = false
        } catch let error as APIError {
            isLoading = false
            if case .server(let code, _) = error, code == "not_found" { isClosed = true }
            else if messages.isEmpty { errorMessage = "No se pudo cargar la conversacion." }
        } catch {
            isLoading = false
            if messages.isEmpty { errorMessage = "No se pudo cargar la conversacion." }
        }
    }

    func loadOlder() async {
        guard hasMore, !isLoadingOlder, let oldest = messages.first(where: { sendStates[$0.clientId ?? ""] == nil }) else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        if let response: MessagesResponse = try? await api.send(.messages(matchID: match.id, before: oldest.id)) {
            merge(response.messages.reversed())
            hasMore = response.hasMore
        }
    }

    // MARK: - Envio

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2000 else { return }
        draft = ""
        deliver(text: text, clientID: UUID().uuidString)
    }

    func retry(_ message: ChatMessage) {
        guard let clientID = message.clientId, sendStates[clientID] == .failed, let body = message.body else { return }
        deliver(text: body, clientID: clientID)
    }

    private func deliver(text: String, clientID: String) {
        let local = ChatMessage(id: "local-\(clientID)", clientId: clientID, senderId: myID, mine: true, kind: "text",
                                body: text, imageUrl: nil, readAt: nil, createdAt: .now)
        if let index = messages.firstIndex(where: { $0.clientId == clientID }) { messages[index] = local }
        else { messages.append(local) }
        sendStates[clientID] = .sending

        Task {
            do {
                let response: MessageResponse = try await api.send(.sendMessage(matchID: match.id),
                                                                  body: SendMessageRequest(body: text, clientId: clientID))
                sendStates[clientID] = nil
                reconcile(response.message)
            } catch let error as APIError {
                if case .server(let code, _) = error, code == "not_found" { isClosed = true; sendStates[clientID] = nil; return }
                sendStates[clientID] = .failed
            } catch {
                sendStates[clientID] = .failed
            }
        }
    }

    // MARK: - Tiempo real

    private func handle(_ event: CableEvent) {
        switch event {
        case .message(let message):
            reconcile(message)
            if !message.mine { Task { await markRead() } }
        case .read(let ids, let readerId):
            guard readerId != myID else { return }
            let now = Date()
            messages = messages.map { ids.contains($0.id) ? $0.with(readAt: now) : $0 }
        case .typing(let userId):
            guard userId != myID else { return }
            otherIsTyping = true
            typingTask?.cancel()
            typingTask = Task {
                try? await Task.sleep(for: .seconds(4))
                if !Task.isCancelled { otherIsTyping = false }
            }
        }
    }

    private func notifyTyping() {
        guard Date().timeIntervalSince(lastTypingSent) > 3 else { return }
        lastTypingSent = .now
        cable.sendTyping(matchID: match.id)
    }

    /// Anade un mensaje o reemplaza el local con el del servidor, sin duplicar.
    private func reconcile(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id || ($0.clientId != nil && $0.clientId == message.clientId) }) {
            messages[index] = message
        } else {
            messages.append(message)
            messages.sort { $0.createdAt < $1.createdAt }
        }
        if let clientID = message.clientId { sendStates[clientID] = nil }
    }

    private func merge(_ incoming: [ChatMessage]) {
        for message in incoming { reconcile(message) }
    }

    func markRead() async {
        guard messages.contains(where: { !$0.mine && $0.readAt == nil }) else { return }
        try? await api.send(.markRead(matchID: match.id))
        let now = Date()
        messages = messages.map { !$0.mine && $0.readAt == nil ? $0.with(readAt: now) : $0 }
    }

    // MARK: - Acciones

    func unmatch() async -> Bool {
        do { try await api.send(.unmatch(id: match.id)); return true }
        catch { errorMessage = "No se pudo deshacer el match."; return false }
    }
}
