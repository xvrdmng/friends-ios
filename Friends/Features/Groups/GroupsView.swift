import SwiftUI

/// Grupos por categoría e intereses (M3). Dentro de cada grupo hay su propio mazo.
struct GroupsView: View {
    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()
            Text("GROUPS")
                .font(.lazyHeading)
                .padding(16)
                .lazyCard(backgroundColor: .cardCyan)
        }
    }
}
