import Foundation

struct InterestItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let emoji: String?
    let category: String
}

struct InterestsResponse: Decodable, Sendable {
    let interests: [InterestItem]
}

struct LanguageItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let code: String
    let name: String
}

struct LanguagesResponse: Decodable, Sendable {
    let languages: [LanguageItem]
}

/// Idioma del usuario: `native` no lleva nivel; `learning` si (a1...c2).
struct LanguageEntry: Encodable, Sendable {
    let languageId: String
    let kind: String
    let level: String?

    enum CodingKeys: String, CodingKey {
        case languageId = "language_id"
        case kind, level
    }
}

struct PhotoItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let url: String
    let thumbUrl: String
    // Anadidos para el mazo y el gestor de fotos (opcionales: el resto del codigo no cambia).
    var position: Int? = nil
    var state: String? = nil

    var imageURL: URL? { URL(string: url) }
    var thumbURL: URL? { URL(string: thumbUrl) }
    var isApproved: Bool { state == nil || state == "approved" }
}

struct PhotoResponse: Decodable, Sendable {
    let photo: PhotoItem
}

/// Un paso del wizard manda solo los campos que toca. Las claves van en
/// snake_case explicito porque el encoder no convierte (lo exige WebAuthn).
struct OnboardingPayload: Encodable, Sendable {
    var displayName: String?
    var birthdate: String?
    var gender: String?
    var datingPreference: String?
    var modeDating: Bool?
    var modeFriendship: Bool?
    var modeLanguage: Bool?
    var interestIds: [String]?
    var languages: [LanguageEntry]?
    var bio: String?
    var occupation: String?
    var education: String?
    var heightCm: Int?
    var kids: String?
    var wantsKids: String?
    var smoking: String?
    var drinking: String?
    var relationshipGoal: String?
    var completed: String?

    enum CodingKeys: String, CodingKey {
        case displayName      = "display_name"
        case birthdate
        case gender
        case datingPreference = "dating_preference"
        case modeDating       = "mode_dating"
        case modeFriendship   = "mode_friendship"
        case modeLanguage     = "mode_language"
        case interestIds      = "interest_ids"
        case languages
        case bio, occupation, education
        case heightCm         = "height_cm"
        case kids
        case wantsKids        = "wants_kids"
        case smoking, drinking
        case relationshipGoal = "relationship_goal"
        case completed
    }
}

/// GET /me. Todo lo del perfil es opcional: un usuario recien creado no tiene
/// perfil y el servidor devuelve `{ "profile": null }`.
struct MeResponse: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let id: String
        let handle: String
        let onboardingCompleted: Bool
        // Premium y limites (opcionales: anadidos para el paywall y el mazo).
        var premium: Bool? = nil
        var premiumUntil: Date? = nil
        var likesLeftToday: Int? = nil
    }

    struct Profile: Decodable, Sendable {
        var displayName: String?
        var birthdate: String?
        var gender: String?
        var datingPreference: String?
        var modeDating: Bool?
        var modeFriendship: Bool?
        var modeLanguage: Bool?
        var bio: String?
        var kids: String?
        var smoking: String?
        var relationshipGoal: String?
        // Anadidos para la pantalla de perfil (opcionales).
        var age: Int? = nil
        var occupation: String? = nil
        var education: String? = nil
        var heightCm: Int? = nil
        var wantsKids: String? = nil
        var drinking: String? = nil
        var city: String? = nil
        var located: Bool? = nil
    }

    struct Language: Decodable, Sendable {
        let languageId: String
        let kind: String
        let level: String?
    }

    let user: User
    let profile: Profile?
    let photos: [PhotoItem]?
    let interestIds: [String]?
    let languages: [Language]?
}
