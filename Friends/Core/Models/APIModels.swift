import CoreLocation
import Foundation

// Modelos de respuesta de la API. El decodificador convierte snake_case a
// camelCase, asi que aqui los nombres son los habituales de Swift.

struct PhotosResponse: Decodable, Sendable { let photos: [PhotoItem] }

/// Una carta del mazo. Nunca lleva coordenadas ni fecha de nacimiento: solo la
/// distancia en km enteros (0 = menos de 1 km).
struct DeckCard: Decodable, Identifiable, Hashable, Sendable {
    let userId: String
    let displayName: String
    let age: Int?
    let bio: String?
    let occupation: String?
    let city: String?
    let distanceKm: Int?
    let gender: String?
    let heightCm: Int?
    let kids: String?
    let smoking: String?
    let drinking: String?
    let relationshipGoal: String?
    let education: String?
    let verified: Bool
    let sharedInterestCount: Int
    let interests: [CardInterest]
    let languages: [CardLanguage]
    let photos: [PhotoItem]

    var id: String { userId }
}

struct CardInterest: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let emoji: String?
    let shared: Bool
}

struct CardLanguage: Decodable, Hashable, Sendable {
    let code: String
    let name: String
    let kind: String      // native | learning
    let level: String?
}

struct DeckResponse: Decodable, Sendable {
    let context: String
    let cards: [DeckCard]
    let likesLeftToday: Int?
}

struct Person: Decodable, Identifiable, Hashable, Sendable {
    let userId: String
    let displayName: String
    let age: Int?
    let thumbUrl: URL?
    var role: String? = nil
    /// Solo en los likes recibidos: en que modo te dio like (dating, friendship, language).
    var context: String? = nil

    var id: String { userId }
}

struct GroupRef: Decodable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
}

struct ChatMessage: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let clientId: String?
    let senderId: String
    let mine: Bool
    let kind: String
    let body: String?
    let imageUrl: URL?
    let readAt: Date?
    let createdAt: Date

    func with(readAt: Date?) -> ChatMessage {
        ChatMessage(id: id, clientId: clientId, senderId: senderId, mine: mine, kind: kind,
                    body: body, imageUrl: imageUrl, readAt: readAt, createdAt: createdAt)
    }
}

struct MessageResponse: Decodable, Sendable { let message: ChatMessage }
struct MessagesResponse: Decodable, Sendable {
    let messages: [ChatMessage]
    let hasMore: Bool
}

struct Match: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let context: String
    let group: GroupRef?
    let other: Person
    let createdAt: Date
    var lastMessage: ChatMessage?
    var unreadCount: Int
}

struct MatchesResponse: Decodable, Sendable { let matches: [Match] }

struct LikeResponse: Decodable, Sendable {
    struct Like: Decodable, Sendable { let id: String; let decision: String }
    let like: Like
    let match: Match?
    let likesLeftToday: Int?
}

struct ReceivedLikesResponse: Decodable, Sendable {
    let count: Int
    let premium: Bool
    /// Cuantos hay en cada modo, aunque no seas premium.
    var counts: [String: Int]? = nil
    let people: [Person]?
}

/// (No se llama `Group` para no ocultar el `Group` de SwiftUI.)
struct FriendGroup: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let category: String
    let visibility: String
    let status: String
    let city: String?
    let membersCount: Int
    let coverUrl: URL?
    let interests: [InterestItem]
    let isMember: Bool
    let role: String?
    let distanceKm: Int?
    // Un grupo es un sitio: sus coordenadas vienen redondeadas a ~1 km.
    var lat: Double? = nil
    var lng: Double? = nil
    /// pending | rejected cuando pediste entrar a un grupo privado; nil si no.
    var myRequest: String? = nil
    /// Solo lo ve quien modera.
    var pendingRequestsCount: Int? = nil

    var isOwner: Bool { role == "owner" }
    var canModerate: Bool { role == "owner" || role == "moderator" }
    var isPrivate: Bool { visibility == "private_group" }
    var hasRequested: Bool { myRequest == "pending" }
    var wasRejected: Bool { myRequest == "rejected" }
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct GroupsResponse: Decodable, Sendable { let groups: [FriendGroup] }
struct GroupResponse: Decodable, Sendable { let group: FriendGroup }
struct MembersResponse: Decodable, Sendable { let members: [Person] }
struct JoinResponse: Decodable, Sendable {
    let joined: Bool
    /// true si el grupo es privado y la peticion quedo pendiente del admin.
    var requested: Bool? = nil
}

struct JoinRequestItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let displayName: String
    let age: Int?
    let thumbUrl: URL?
    let status: String
}

struct JoinRequestsResponse: Decodable, Sendable { let requests: [JoinRequestItem] }

struct FiltersResponse: Decodable, Sendable {
    var distanceKm: Int
    var ageMin: Int
    var ageMax: Int
    var advanced: [String: [String]]
    let maxDistanceKm: Int
    let premium: Bool
}

struct BlocksResponse: Decodable, Sendable { let blocks: [Person] }

/// Al desbloquear vuelven los matches que rompio ese bloqueo, con su
/// conversacion intacta. Puede venir vacio: si el otro te sigue bloqueando, o
/// si el match se deshizo a mano, no vuelve nada.
struct UnblockResponse: Decodable, Sendable {
    let unblocked: Bool
    let restoredMatches: [Match]
}

struct SubscriptionResponse: Decodable, Sendable {
    let premium: Bool
    let premiumUntil: Date?
}

// MARK: - Cuerpos de peticion

struct LikeRequest: Encodable, Sendable {
    let toUserId: String
    let context: String
    let decision: String
    var groupId: String? = nil
}

struct SendMessageRequest: Encodable, Sendable {
    let body: String
    let clientId: String
}

struct ReportRequest: Encodable, Sendable {
    let reportableType: String
    let reportableId: String
    let reason: String
    var note: String? = nil
    var block: Bool = false
}

struct BlockRequest: Encodable, Sendable { let userId: String }
struct DeviceRequest: Encodable, Sendable { let token: String; let environment: String }
struct OrderRequest: Encodable, Sendable { let ids: [String] }
struct SyncRequest: Encodable, Sendable { let signedTransaction: String }

struct LocationRequest: Encodable, Sendable {
    let lat: Double
    let lng: Double
    var city: String? = nil
    var country: String? = nil
}

struct FiltersRequest: Encodable, Sendable {
    var distanceKm: Int? = nil
    var ageMin: Int? = nil
    var ageMax: Int? = nil
    var advanced: [String: [String]]? = nil
}

struct CreateGroupRequest: Encodable, Sendable {
    let name: String
    let description: String
    let category: String
    let visibility: String
    let interestIds: [String]
    let useMyLocation: Bool
}


struct EnabledRequest: Encodable, Sendable { let enabled: Bool }
