import SwiftUI

/// Chip seleccionable en estilo sticker. Es el control basico del wizard:
/// genero, preferencias, intereses y respuestas de "sobre ti".
struct ChoiceChip: View {
    let label: String
    var emoji: String?
    var selectedColor: Color = .lazyRose
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji { Text(emoji) }
                Text(label)
                    .font(.lazySubhead)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .lazyCard(
                backgroundColor: isSelected ? selectedColor : .white,
                cornerRadius: 18,
                offset: isSelected ? 2 : 4
            )
            .offset(x: isSelected ? 2 : 0, y: isSelected ? 2 : 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.lazyBlack)
        .animation(.snappy(duration: 0.15), value: isSelected)
    }
}

/// Distribuye chips en filas que se ajustan al ancho disponible.
struct ChipFlow: Layout {
    var spacing: CGFloat = 10

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
