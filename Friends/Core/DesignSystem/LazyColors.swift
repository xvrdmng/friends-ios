import SwiftUI

/// Tokens de color de la marca toolazy.
///
/// Fuente de verdad: `toolazy/app/assets/tailwind/application.css` (@theme), que es
/// la marca publicada. Ojo: `toolazytooplay-ios` tiene hoy valores distintos para
/// rosa, morado y crema — hay que alinearlo con estos.
extension Color {
    static let lazyAcid      = Color(hex: "#CCFF00")
    static let lazyBubblegum = Color(hex: "#FF90E8")
    static let lazyCyan      = Color(hex: "#00F0FF")
    static let lazyPurple    = Color(hex: "#A855F7")
    static let lazyCream     = Color(hex: "#FFFEF0")
    static let lazyHeroBG    = Color(hex: "#E8E4F0")

    /// Fondo de la app. Blanco: deja que el color viva en las tarjetas.
    static let appBackground = Color(hex: "#FAF6F0")
    static let lazyGray      = Color(hex: "#F5F5F7")
    static let lazyBlack     = Color.black
    static let lazyRed       = Color(hex: "#C8392B")
    static let lazyYellow    = Color(hex: "#FFE14D")
    static let lazyRose      = Color(hex: "#F4B6D6")
    static let lazyMint      = Color(hex: "#B9F0D0")
    static let lazyNotice    = Color(hex: "#FBE6BE")

    static let cardPink   = Color(hex: "#FFB8E8")
    static let cardPurple = Color(hex: "#C8A8FF")
    static let cardCyan   = Color(hex: "#7FE5E0")
    static let cardYellow = Color(hex: "#FFF59D")
    static let cardOrange = Color(hex: "#FFB74D")

    static let cardColors: [Color] = [.cardPink, .cardPurple, .cardCyan, .cardYellow, .cardOrange]

    static func cardColor(for index: Int) -> Color {
        cardColors[abs(index) % cardColors.count]
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
