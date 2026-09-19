import SwiftUI

/// Tarjeta sticker: borde negro de 3 px, esquinas redondeadas y sombra dura
/// desplazada abajo a la derecha, sin difuminado.
struct LazyCardModifier: ViewModifier {
    var backgroundColor: Color = .white
    var cornerRadius: CGFloat = 18
    var offset: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.lazyBlack, lineWidth: 3)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.lazyBlack)
                    .offset(x: offset, y: offset)
            )
    }
}

/// Botón sticker: se hunde en su sombra al pulsarlo. `fillsWidth` estira la
/// tarjeta entera, asi toda la superficie visible es pulsable.
struct LazyButtonStyle: ButtonStyle {
    var background: Color = .lazyBlack
    var foreground: Color = .white
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.lazySubhead)
            .textCase(.uppercase)
            .kerning(1)
            .foregroundStyle(foreground)
            .padding(.vertical, 16)
            .padding(.horizontal, 22)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .lazyCard(backgroundColor: background, cornerRadius: 18, offset: pressed ? 0 : 5)
            .offset(x: pressed ? 5 : 0, y: pressed ? 5 : 0)
            .animation(.easeOut(duration: 0.1), value: pressed)
    }
}

extension View {
    func lazyCard(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 18,
        offset: CGFloat = 4
    ) -> some View {
        modifier(LazyCardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            offset: offset
        ))
    }
}
