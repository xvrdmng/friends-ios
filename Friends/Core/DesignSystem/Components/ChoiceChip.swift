import SwiftUI

/// Chip seleccionable. Es el control basico del wizard, los filtros y los
/// grupos: genero, intereses, categorias y respuestas de "sobre ti".
///
/// Se apoya en los estilos de boton del sistema, asi que hereda el tinte, el
/// modo oscuro, Dynamic Type y el feedback al pulsar sin dibujar nada a mano.
struct ChoiceChip: View {
    let label: String
    var emoji: String?
    var tint: Color = .accentColor
    let isSelected: Bool
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        // Los dos estilos de cristal son tipos distintos, asi que la eleccion
        // va en una rama y no en un ternario.
        if isSelected {
            button.buttonStyle(.glassProminent)
        } else {
            // Sin seleccionar el rotulo va en el color de texto normal: tenirlo
            // de acento haria que toda la fila pareciera ya elegida.
            button.buttonStyle(.glass).foregroundStyle(.primary)
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji { Text(emoji) }
                Text(label)
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonBorderShape(.capsule)
        .tint(tint)
        // Sin esto VoiceOver los lee como botones sueltos y no hay forma de
        // saber cuales estan elegidos.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Distribuye chips en filas que se ajustan al ancho disponible.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Etiqueta corta de solo lectura: contexto, contadores, estado.
struct Tag: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: .capsule)
    }
}
