import SwiftUI

/// Tarjeta sticker: borde negro de 3 px + sombra dura desplazada, sin difuminado.
/// Equivale a `--shadow-sticker: 4px 4px 0px 0px #000` de la web.
struct LazyCardModifier: ViewModifier {
    var backgroundColor: Color = .white
    var cornerRadius: CGFloat = 12
    var offset: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.lazyBlack, lineWidth: 3)
            )
            .shadow(color: .lazyBlack, radius: 0, x: offset, y: offset)
    }
}

/// Botón primario en estilo toolazy: se hunde al pulsarlo, como en la web.
struct LazyButtonStyle: ButtonStyle {
    var background: Color = .lazyBlack
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lazySubhead)
            .textCase(.uppercase)
            .kerning(0.7)
            .foregroundStyle(foreground)
            .padding(.vertical, 14)
            .padding(.horizontal, 26)
            .lazyCard(backgroundColor: background, offset: configuration.isPressed ? 0 : 4)
            .offset(
                x: configuration.isPressed ? 4 : 0,
                y: configuration.isPressed ? 4 : 0
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func lazyCard(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 12,
        offset: CGFloat = 4
    ) -> some View {
        modifier(LazyCardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            offset: offset
        ))
    }
}
