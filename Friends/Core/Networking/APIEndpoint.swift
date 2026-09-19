import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", patch = "PATCH", put = "PUT", delete = "DELETE"
}

/// Espejo de `config/routes.rb` de friends-api.
enum APIEndpoint: Sendable {
    case registrationOptions, registration
    case sessionOptions, session, signOut
    case me, updateMe, onboarding, location
    case interests, languages
    case deck(context: DeckContext, groupID: String?)
    case like
    case matches
    case messages(matchID: String)

    var method: HTTPMethod {
        switch self {
        case .me, .interests, .languages, .deck, .matches, .messages: .get
        case .updateMe, .onboarding: .patch
        case .location: .put
        case .signOut: .delete
        default: .post
        }
    }

    var path: String {
        switch self {
        case .registrationOptions: "/api/v1/auth/registration/options"
        case .registration:        "/api/v1/auth/registration"
        case .sessionOptions:      "/api/v1/auth/session/options"
        case .session, .signOut:   "/api/v1/auth/session"
        case .me, .updateMe:       "/api/v1/me"
        case .onboarding:          "/api/v1/me/onboarding"
        case .location:            "/api/v1/me/location"
        case .interests:           "/api/v1/interests"
        case .languages:           "/api/v1/languages"
        case .deck:                "/api/v1/deck"
        case .like:                "/api/v1/likes"
        case .matches:             "/api/v1/matches"
        case .messages(let id):    "/api/v1/matches/\(id)/messages"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .deck(let context, let groupID):
            var items = [URLQueryItem(name: "context", value: context.rawValue)]
            if let groupID { items.append(URLQueryItem(name: "group_id", value: groupID)) }
            return items
        default:
            return []
        }
    }

    /// Los catálogos se cachean; todo lo demás es estado vivo.
    var isCacheable: Bool {
        switch self {
        case .interests, .languages: true
        default: false
        }
    }
}

enum DeckContext: String, Codable, Sendable, CaseIterable {
    case dating, friendship, language, group
}
