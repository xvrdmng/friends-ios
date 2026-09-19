import SwiftUI

/// Inter 900 para titulares, JetBrains Mono para microcopy.
/// Hasta que se empaqueten las fuentes en Resources, cae en la fuente del sistema
/// con los mismos pesos: el peso .black es lo que hace reconocible al titular.
extension Font {
    static let lazyDisplay = Font.system(size: 48, weight: .black)
    static let lazyTitle   = Font.system(size: 40, weight: .black)
    static let lazyHeading = Font.system(size: 30, weight: .black)
    static let lazySubhead = Font.system(size: 22, weight: .bold)
    static let lazyBody    = Font.system(size: 19, weight: .regular)
    static let lazyCaption = Font.system(size: 16, weight: .medium)
    /// Microcopy: edad, distancia, etiquetas de estado.
    static let lazyMono    = Font.system(size: 15, weight: .bold, design: .monospaced)
}
