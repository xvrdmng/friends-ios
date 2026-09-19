import SwiftUI

/// Navegación principal.
///
/// En iOS 27 la tab bar ya es Liquid Glass: el trabajo no es pintarla, es no
/// taparla. Todo el color de marca vive en el contenido, no en el chrome.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Date", systemImage: "heart.fill") {
                DeckView(context: .dating)
            }
            Tab("Friends", systemImage: "person.2.fill") {
                DeckView(context: .friendship)
            }
            Tab("Groups", systemImage: "square.grid.2x2.fill") {
                GroupsView()
            }
            Tab("Chats", systemImage: "bubble.left.fill") {
                MatchesListView()
            }
            Tab("Profile", systemImage: "person.crop.circle.fill") {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.lazyBlack)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()
            Text("FRIENDS")
                .font(.lazyDisplay)
                .kerning(-1)
        }
    }
}
