import SwiftUI

/// Identidad visual de cada modo. Son colores del sistema a proposito: se
/// adaptan solos al modo oscuro, a Aumentar contraste y a la vibrancia sobre
/// material, cosa que un hex fijo no hace.
extension DeckContext {
    var tint: Color {
        switch self {
        case .dating:     .pink
        case .friendship: .teal
        case .language:   .indigo
        case .group:      .orange
        }
    }

    var symbol: String {
        switch self {
        case .dating:     "heart.fill"
        case .friendship: "person.2.fill"
        case .language:   "character.bubble.fill"
        case .group:      "person.3.fill"
        }
    }

    var title: String {
        switch self {
        case .dating:     "Citas"
        case .friendship: "Amistad"
        case .language:   "Idiomas"
        case .group:      "Grupo"
        }
    }
}

/// Error que se ensena con `.alert`. Sustituye al toast propio: en iOS un fallo
/// se cuenta con una alerta que hay que reconocer, no con un aviso que se va
/// solo antes de que VoiceOver llegue a leerlo.
struct AlertMessage: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String?

    init(_ title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }
}

extension View {
    /// Alerta de error estandar: un solo boton para cerrar.
    func errorAlert(_ error: Binding<AlertMessage?>) -> some View {
        alert(
            error.wrappedValue?.title ?? "",
            isPresented: Binding(get: { error.wrappedValue != nil },
                                 set: { if !$0 { error.wrappedValue = nil } }),
            presenting: error.wrappedValue
        ) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { message in
            if let text = message.message { Text(text) }
        }
    }
}
