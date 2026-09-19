import SwiftUI

/// Matches y sus chats (M2). Un match nace con su conversación ya creada.
struct MatchesListView: View {
    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()
            Text("CHATS")
                .font(.lazyHeading)
                .padding(16)
                .lazyCard(backgroundColor: .cardYellow)
        }
    }
}
