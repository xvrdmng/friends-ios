import SwiftUI

/// Perfil propio y filtros de búsqueda (M2).
struct ProfileView: View {
    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()
            Text("PROFILE")
                .font(.lazyHeading)
                .padding(16)
                .lazyCard(backgroundColor: .cardPurple)
        }
    }
}
