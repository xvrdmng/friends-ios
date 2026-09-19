import CoreGraphics

/// Reglas del gesto de swipe, sin SwiftUI para poder probarlas.
enum SwipeMath {
    enum Outcome: Equatable { case like, pass, superlike, none }

    /// Distancia horizontal que confirma la decision.
    static let horizontalThreshold: CGFloat = 120
    /// Distancia vertical (hacia arriba) que confirma un superlike.
    static let verticalThreshold: CGFloat = 140
    /// Un flick rapido tambien cuenta aunque el dedo no haya recorrido tanto.
    static let flickDistance: CGFloat = 260

    /// `translation` es donde esta el dedo; `predicted` es donde terminaria por inercia.
    static func outcome(translation: CGSize, predicted: CGSize) -> Outcome {
        let upward = -translation.height > verticalThreshold && abs(translation.height) > abs(translation.width)
        if upward { return .superlike }

        if translation.width > horizontalThreshold || predicted.width > flickDistance && translation.width > 40 { return .like }
        if translation.width < -horizontalThreshold || predicted.width < -flickDistance && translation.width < -40 { return .pass }
        return .none
    }

    /// Giro de la carta segun cuanto se arrastra (maximo ±12 grados).
    static func rotation(forWidth width: CGFloat) -> Double {
        max(-12, min(12, Double(width) / 18))
    }

    /// Opacidad del sello LIKE/NOPE: 0 en reposo, 1 al llegar al umbral.
    static func stampOpacity(forWidth width: CGFloat, positive: Bool) -> Double {
        let value = positive ? width : -width
        return max(0, min(1, Double(value) / Double(horizontalThreshold)))
    }
}
