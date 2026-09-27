import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", patch = "PATCH", put = "PUT", delete = "DELETE"
}

enum DeckContext: String, Codable, Sendable, CaseIterable {
    case dating, friendship, language, group
}

enum GroupScope: String, Sendable { case discover, mine }

/// Espejo de `config/routes.rb` de friends-api.
enum APIEndpoint: Sendable {
    // Autenticacion
    case devSession, devPremium
    case registrationOptions, registration
    case sessionOptions, session, signOut

    // Perfil
    case me, updateMe, deleteMe, exportMe
    case onboarding, location
    case photos, photo(id: String), orderPhotos
    case filters, updateFilters
    case interests, languages

    // Descubrimiento
    case deck(context: DeckContext, groupSlug: String?)
    case like, likesReceived(context: DeckContext?), rewind

    // Matches y chat
    case matches, unmatch(id: String)
    case messages(matchID: String, before: String?)
    case sendMessage(matchID: String)
    case markRead(matchID: String)

    // Grupos
    case groups(scope: GroupScope, category: String?, query: String?)
    case createGroup
    case group(slug: String)
    case groupCover(slug: String)
    case join(slug: String), leave(slug: String)
    case members(slug: String)
    case kick(slug: String, userID: String)
    case groupRequests(slug: String)
    case approveRequest(slug: String, id: String), rejectRequest(slug: String, id: String)
    case cancelRequest(slug: String)

    // Seguridad
    case blocks, block, unblock(userID: String)
    case report
    case registerDevice, unregisterDevice(token: String)

    // Premium
    case syncSubscription

    var method: HTTPMethod {
        switch self {
        case .me, .exportMe, .photos, .filters, .interests, .languages, .deck, .likesReceived,
             .matches, .messages, .groups, .group, .members, .blocks, .groupRequests:
            .get
        case .updateMe: .patch
        case .onboarding, .orderPhotos, .updateFilters, .groupCover: .patch
        case .location: .put
        case .deleteMe, .signOut, .photo, .unmatch, .leave, .kick, .unblock, .unregisterDevice, .cancelRequest: .delete
        default: .post
        }
    }

    var path: String {
        switch self {
        case .devSession:           "/api/v1/auth/dev_session"
        case .devPremium:           "/api/v1/auth/dev_premium"
        case .registrationOptions:  "/api/v1/auth/registration/options"
        case .registration:         "/api/v1/auth/registration"
        case .sessionOptions:       "/api/v1/auth/session/options"
        case .session, .signOut:    "/api/v1/auth/session"
        case .me, .updateMe, .deleteMe: "/api/v1/me"
        case .exportMe:             "/api/v1/me/export"
        case .onboarding:           "/api/v1/me/onboarding"
        case .location:             "/api/v1/me/location"
        case .photos:               "/api/v1/me/photos"
        case .photo(let id):  "/api/v1/me/photos/\(id)"
        case .orderPhotos:          "/api/v1/me/photos/order"
        case .filters, .updateFilters: "/api/v1/me/filters"
        case .interests:            "/api/v1/interests"
        case .languages:            "/api/v1/languages"
        case .deck(_, let slug):    slug.map { "/api/v1/groups/\($0)/deck" } ?? "/api/v1/deck"
        case .like:                 "/api/v1/likes"
        case .likesReceived:        "/api/v1/likes/received"
        case .rewind:               "/api/v1/likes/rewind"
        case .matches:              "/api/v1/matches"
        case .unmatch(let id):      "/api/v1/matches/\(id)"
        case .messages(let id, _), .sendMessage(let id): "/api/v1/matches/\(id)/messages"
        case .markRead(let id):     "/api/v1/matches/\(id)/read"
        case .groups, .createGroup: "/api/v1/groups"
        case .group(let slug):      "/api/v1/groups/\(slug)"
        case .groupCover(let slug): "/api/v1/groups/\(slug)/cover"
        case .join(let slug), .leave(let slug): "/api/v1/groups/\(slug)/membership"
        case .groupRequests(let slug): "/api/v1/groups/\(slug)/requests"
        case .approveRequest(let slug, let id): "/api/v1/groups/\(slug)/requests/\(id)/approve"
        case .rejectRequest(let slug, let id):  "/api/v1/groups/\(slug)/requests/\(id)/reject"
        case .cancelRequest(let slug): "/api/v1/groups/\(slug)/request"
        case .members(let slug):    "/api/v1/groups/\(slug)/members"
        case .kick(let slug, let uid): "/api/v1/groups/\(slug)/members/\(uid)"
        case .blocks, .block:       "/api/v1/blocks"
        case .unblock(let uid):     "/api/v1/blocks/\(uid)"
        case .report:               "/api/v1/reports"
        case .registerDevice:       "/api/v1/devices"
        case .unregisterDevice(let token): "/api/v1/devices/\(token)"
        case .syncSubscription:     "/api/v1/subscriptions/sync"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .deck(let context, let slug):
            slug == nil ? [URLQueryItem(name: "context", value: context.rawValue)] : []
        case .likesReceived(let context):
            context.map { [URLQueryItem(name: "context", value: $0.rawValue)] } ?? []
        case .messages(_, let before):
            before.map { [URLQueryItem(name: "before", value: $0)] } ?? []
        case .groups(let scope, let category, let query):
            [URLQueryItem(name: "scope", value: scope.rawValue),
             category.map { URLQueryItem(name: "category", value: $0) },
             query.flatMap { $0.isEmpty ? nil : URLQueryItem(name: "q", value: $0) }].compactMap { $0 }
        default:
            []
        }
    }

    /// Los catalogos casi no cambian: se cachean. Todo lo demas es estado vivo.
    var isCacheable: Bool {
        switch self {
        case .interests, .languages: true
        default: false
        }
    }
}
