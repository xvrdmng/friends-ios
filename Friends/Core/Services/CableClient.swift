import Foundation

/// Cliente de ActionCable sobre URLSessionWebSocketTask.
///
/// - Se autentica con el mismo Bearer token de la API (cabecera Authorization).
/// - Se reconecta solo, con espera creciente, y vuelve a suscribirse a todo.
/// - Cada suscripcion recibe un AsyncStream de eventos.
@MainActor
final class CableClient {
    static let shared = CableClient()

    private let baseURL: URL
    private let session = URLSession(configuration: .default)
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var wantsConnection = false

    private var streams: [String: [UUID: AsyncStream<CableEvent>.Continuation]] = [:]   // identifier -> suscriptores
    private var confirmed: Set<String> = []

    init(baseURL: URL? = nil) {
        if let baseURL { self.baseURL = baseURL }
        else {
            let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
            self.baseURL = URL(string: value ?? "https://api.toolazy.cl")!
        }
    }

    // MARK: - API publica

    /// Eventos de una conversacion. Cancelar la iteracion cancela la suscripcion.
    func events(matchID: String) -> AsyncStream<CableEvent> {
        let identifier = CableFrame.identifier(matchID: matchID)
        let token = UUID()
        return AsyncStream { continuation in
            streams[identifier, default: [:]][token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.remove(token: token, identifier: identifier) }
            }
            connectIfNeeded()
            if confirmed.contains(identifier) == false { sendSubscribe(identifier) }
        }
    }

    /// Avisa a la otra persona de que estas escribiendo.
    func sendTyping(matchID: String) {
        let identifier = CableFrame.identifier(matchID: matchID)
        guard confirmed.contains(identifier) else { return }
        send(CableFrame.performCommand(identifier: identifier, action: "typing"))
    }

    func disconnect() {
        wantsConnection = false
        receiveTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        confirmed.removeAll()
    }

    /// Llamar al volver a primer plano: los sockets mueren en segundo plano.
    func reconnectIfNeeded() {
        if !streams.isEmpty { connectIfNeeded() }
    }

    // MARK: - Conexion

    private func connectIfNeeded() {
        wantsConnection = true
        guard task == nil else { return }
        Task { await connect() }
    }

    private func connect() async {
        guard wantsConnection, task == nil, let token = await SessionStore.shared.token else { return }

        var components = URLComponents(url: baseURL.appendingPathComponent("cable"), resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("actioncable-v1-json", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        let socket = session.webSocketTask(with: request)
        task = socket
        socket.resume()
        receiveTask = Task { [weak self] in await self?.receiveLoop(socket) }
    }

    private func receiveLoop(_ socket: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await socket.receive()
                guard case .string(let text) = message else { continue }
                handle(CableFrame.parse(text))
            } catch {
                break
            }
        }
        // El socket murio: se reintenta con espera creciente (1, 2, 4... hasta 30 s).
        guard task === socket else { return }
        task = nil
        confirmed.removeAll()
        guard wantsConnection, !streams.isEmpty else { return }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 30)
        try? await Task.sleep(for: .seconds(delay))
        await connect()
    }

    private func handle(_ frame: CableFrame) {
        switch frame {
        case .welcome:
            reconnectAttempt = 0
            for identifier in streams.keys { sendSubscribe(identifier) }
        case .confirmSubscription(let identifier):
            confirmed.insert(identifier)
        case .rejectSubscription(let identifier):
            // Sin acceso (match deshecho, bloqueo): se cierran esas suscripciones.
            streams[identifier]?.values.forEach { $0.finish() }
            streams[identifier] = nil
        case .disconnect(_, let reconnect):
            if !reconnect { disconnect() }
        case .data(let identifier, let payload):
            guard let event = CableEventDecoder.decode(payload) else { return }
            streams[identifier]?.values.forEach { $0.yield(event) }
        case .ping, .unknown:
            break
        }
    }

    private func sendSubscribe(_ identifier: String) {
        send(CableFrame.subscribeCommand(identifier: identifier))
    }

    private func send(_ text: String) {
        task?.send(.string(text)) { _ in }
    }

    private func remove(token: UUID, identifier: String) {
        streams[identifier]?[token] = nil
        if streams[identifier]?.isEmpty == true { streams[identifier] = nil }
        if streams.isEmpty { disconnect() }
    }
}
