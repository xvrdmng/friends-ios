import SwiftUI

/// Navegacion principal. `TabView` nativo: la barra ya es Liquid Glass, se
/// encoge sola al bajar (`tabBarMinimizeBehavior`) y trae de serie el
/// comportamiento de accesibilidad y las adaptaciones por tamano de pantalla.
struct RootView: View {
    let session: SessionViewModel

    @State private var selection: AppTab = .date

    /// Los rotulos son tambien el contrato de `TabsUITests`, que busca los
    /// botones de la barra por estos nombres.
    private enum AppTab: Hashable {
        case date, friends, groups, chats, profile

        var title: String {
            switch self {
            case .date: "Date"
            case .friends: "Friends"
            case .groups: "Groups"
            case .chats: "Chats"
            case .profile: "Profile"
            }
        }

        var symbol: String {
            switch self {
            case .date: "heart.fill"
            case .friends: "person.2.fill"
            case .groups: "person.3.fill"
            case .chats: "bubble.left.and.bubble.right.fill"
            case .profile: "person.crop.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.date.title, systemImage: AppTab.date.symbol, value: AppTab.date) {
                DeckView(context: .dating)
            }
            Tab(AppTab.friends.title, systemImage: AppTab.friends.symbol, value: AppTab.friends) {
                DeckView(context: .friendship)
            }
            Tab(AppTab.groups.title, systemImage: AppTab.groups.symbol, value: AppTab.groups) {
                GroupsView()
            }
            Tab(AppTab.chats.title, systemImage: AppTab.chats.symbol, value: AppTab.chats) {
                MatchesListView()
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                ProfileView(session: session)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// Pantalla de arranque mientras se valida la sesion contra el servidor.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityLabel("Cargando Friends")
    }
}
