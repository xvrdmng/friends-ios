import Foundation

/// El backend devuelve `{"error": {"code": "...", "message": "..."}}` con códigos
/// estables, para que el cliente decida qué hacer sin parsear texto.
struct APIErrorPayload: Decodable, Sendable {
    struct Body: Decodable, Sendable {
        let code: String
        let message: String
    }
    let error: Body
}

enum APIError: Error, Sendable {
    case unauthorized
    case server(code: String, message: String)
    case http(status: Int)
    case decoding(any Error)
    case offline
    case unknown

    /// Se alcanzó el límite diario de likes del plan gratuito: abre el paywall.
    var isLikeLimit: Bool {
        if case .server(let code, _) = self { return code == "like_limit_reached" }
        return false
    }
}
