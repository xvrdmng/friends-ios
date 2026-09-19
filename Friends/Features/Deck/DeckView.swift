import SwiftUI

/// El mazo de swipe (M2).
///
/// El mismo componente sirve para citas, amistad, idiomas y grupos: lo único que
/// cambia es el `context` con el que se pide el mazo al servidor.
struct DeckView: View {
    let context: DeckContext

    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()
            Text(context.rawValue.uppercased())
                .font(.lazyMono)
                .padding(12)
                .lazyCard(backgroundColor: .cardPink)
        }
    }
}
