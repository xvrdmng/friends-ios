import Foundation

/// Textos de las opciones del servidor (enums) en espanol.
enum Labels {
    static let contexts = ["dating": "Citas", "friendship": "Amistad", "language": "Idiomas", "group": "Grupo"]
    static let categories: [String: (name: String, emoji: String)] = [
        "sports": ("Deporte", "⚽"), "music": ("Música", "🎧"), "food": ("Comida", "🍜"), "travel": ("Viajes", "🧳"),
        "gaming": ("Juegos", "🎮"), "arts": ("Arte", "🎨"), "outdoors": ("Aire libre", "🏕️"),
        "learning": ("Aprender", "📚"), "nightlife": ("Noche", "🌙"), "wellness": ("Bienestar", "🧘")
    ]
    static let kids = ["no_kids": "Sin hijos", "kids_living_with": "Tiene hijos, viven con ella/él",
                       "kids_not_living_with": "Tiene hijos, no viven con ella/él", "kids_private": "Prefiere no decirlo"]
    static let smoking = ["smokes_no": "No fuma", "smokes_sometimes": "Fuma a veces", "smokes_yes": "Fuma"]
    static let drinking = ["drinks_no": "No bebe", "drinks_sometimes": "Bebe a veces", "drinks_yes": "Bebe"]
    static let goal = ["serious": "Algo serio", "casual": "Algo casual", "unsure": "Ya veremos", "friendship_only": "Solo amistad"]
    static let education = ["school": "Escolar", "technical": "Técnica", "university": "Universitaria", "postgraduate": "Posgrado"]

    static func distance(_ km: Int?) -> String? {
        guard let km else { return nil }
        return km == 0 ? "a menos de 1 km" : "a \(km) km"
    }
}

/// Las dos paginas que Apple exige tener a la vista en una app de suscripcion.
/// Estan aqui, y no escritas a mano en cada pantalla, para que el paywall y el
/// perfil no puedan acabar apuntando a sitios distintos.
enum LegalLinks {
    static let terms = URL(string: "https://toolazy.cl/friends/terminos")!
    static let privacy = URL(string: "https://toolazy.cl/friends/privacidad")!
}
