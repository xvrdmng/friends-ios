import Foundation

/// Estado del mazo de un contexto (citas, amistad, idiomas o un grupo).
///
/// - Las cartas salen de inmediato (UI optimista) y el like/pass viaja en segundo plano.
/// - Si el servidor rechaza (limite diario), la carta VUELVE al mazo y se abre el paywall.
/// - El mazo se recarga solo cuando quedan pocas, sin duplicar cartas.
@MainActor
@Observable
final class DeckViewModel {
    enum Phase: Equatable {
        case loading
        case ready
        case empty
        case failed(String)
        /// El servidor pide algo antes de poder armar el mazo.
        case needs(Requirement)
    }

    enum Requirement: Equatable {
        case location, mode, languages, completeProfile
    }

    enum Decision: String { case like, pass, superlike }

    static let refillThreshold = 5

    private(set) var cards: [DeckCard] = []
    private(set) var phase: Phase = .loading
    private(set) var likesLeft: Int?
    private(set) var lastSwiped: (card: DeckCard, decision: Decision)?
    private(set) var newMatch: Match?
    var showPaywall = false
    var error: AlertMessage?

    let context: DeckContext
    let groupSlug: String?
    let groupID: String?

    private let api: any APIService
    private var seen: Set<String> = []       // ids ya vistos en esta sesion: evita repetir al recargar
    private var isLoadingMore = false
    private var pendingCount = 0             // likes en vuelo

    init(context: DeckContext, groupSlug: String? = nil, groupID: String? = nil, api: any APIService = APIClient.shared) {
        self.context = context
        self.groupSlug = groupSlug
        self.groupID = groupID
        self.api = api
    }

    var topCard: DeckCard? { cards.first }
    var canRewind: Bool { lastSwiped != nil }

    // MARK: - Carga

    func load(reset: Bool = false) async {
        if reset { cards = []; seen = []; phase = .loading }
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response: DeckResponse = try await api.send(.deck(context: context, groupSlug: groupSlug))
            likesLeft = response.likesLeftToday
            let fresh = response.cards.filter { !seen.contains($0.id) }
            fresh.forEach { seen.insert($0.id) }
            cards.append(contentsOf: fresh)
            phase = cards.isEmpty ? .empty : .ready
        } catch let error as APIError {
            phase = Self.phase(for: error, keepingCards: !cards.isEmpty)
        } catch {
            phase = cards.isEmpty ? .failed("No se pudo cargar. Revisa tu conexion.") : .ready
        }
    }

    private static func phase(for error: APIError, keepingCards: Bool) -> Phase {
        if case .server(let code, let message) = error {
            switch code {
            case "location_required":         return .needs(.location)
            case "mode_disabled":             return .needs(.mode)
            case "language_profile_required": return .needs(.languages)
            case "profile_incomplete":        return .needs(.completeProfile)
            default:                          return keepingCards ? .ready : .failed(message)
            }
        }
        if case .offline = error { return keepingCards ? .ready : .failed("Sin conexion.") }
        return keepingCards ? .ready : .failed("No se pudo cargar el mazo.")
    }

    private func refillIfNeeded() {
        guard cards.count <= Self.refillThreshold, !isLoadingMore else { return }
        Task { await load() }
    }

    // MARK: - Decisiones

    func decide(_ decision: Decision) {
        guard let card = cards.first else { return }
        cards.removeFirst()
        lastSwiped = (card, decision)
        if cards.isEmpty { phase = .empty }
        refillIfNeeded()

        pendingCount += 1
        Task { await send(decision, for: card) }
    }

    private func send(_ decision: Decision, for card: DeckCard) async {
        defer { pendingCount -= 1 }
        let request = LikeRequest(toUserId: card.userId, context: context.rawValue, decision: decision.rawValue, groupId: groupID)

        for attempt in 1...3 {
            do {
                let response: LikeResponse = try await api.send(.like, body: request)
                likesLeft = response.likesLeftToday
                if let match = response.match { newMatch = match }
                return
            } catch let error as APIError {
                if case .server(let code, _) = error {
                    switch code {
                    case "like_limit_reached":
                        putBack(card); showPaywall = true; return
                    case "premium_required", "superlike_limit_reached":
                        putBack(card); showPaywall = code == "premium_required"
                        self.error = AlertMessage("El superlike es premium"); return
                    default:
                        // Rechazo definitivo (bloqueo, cuenta borrada...): la carta se descarta.
                        return
                    }
                }
                // Red caida: se reintenta con espera creciente.
                if attempt < 3 { try? await Task.sleep(for: .seconds(Double(attempt))) }
            } catch {
                return
            }
        }
        // No se pudo enviar: la carta vuelve para no perder la decision del usuario.
        putBack(card)
        self.error = AlertMessage("Sin conexión", message: "No se pudo enviar tu decisión.")
    }

    private func putBack(_ card: DeckCard) {
        guard !cards.contains(where: { $0.id == card.id }) else { return }
        cards.insert(card, at: 0)
        phase = .ready
        if lastSwiped?.card.id == card.id { lastSwiped = nil }
    }

    /// Deshace la ultima decision (premium). El servidor borra el like; la carta vuelve arriba.
    func rewind() async {
        guard let last = lastSwiped else { return }
        do {
            try await api.send(.rewind)
            putBack(last.card)
            lastSwiped = nil
        } catch let error as APIError {
            if case .server(let code, let message) = error {
                if code == "premium_required" { showPaywall = true }
                else { self.error = AlertMessage("No se pudo deshacer", message: message) }
            }
        } catch {
            self.error = AlertMessage("No se pudo deshacer")
        }
    }

    func dismissMatch() { newMatch = nil }

    /// Quita del mazo a alguien (por ejemplo tras bloquearlo desde la carta).
    func remove(userID: String) {
        cards.removeAll { $0.id == userID }
        if cards.isEmpty { phase = .empty }
    }
}
