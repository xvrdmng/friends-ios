import SwiftUI

/// Navegacion principal. `TabView` nativo: la barra ya es Liquid Glass, se
/// encoge sola al bajar (`tabBarMinimizeBehavior`) y trae de serie el
/// comportamiento de accesibilidad y las adaptaciones por tamano de pantalla.
struct RootView: View {
    let session: SessionViewModel

    @State private var selection: AppTab = .date
    /// Vive aqui, y no dentro de la pestana, para que la barra pueda llevar el
    /// contador de mensajes sin leer estando tu en cualquier otra pestana: una
    /// vista de `TabView` que nadie ha abierto todavia no se crea, asi que un
    /// modelo propio de la pestana Chats no sabria nada hasta entrar en ella.
    @State private var matches = MatchesListViewModel()
    @State private var push = PushService.shared
    @Environment(\.scenePhase) private var scenePhase

    /// Los rotulos son tambien el contrato de `TabsUITests`, que busca los
    /// botones de la barra por estos nombres.
    private enum AppTab: Hashable {
        case date, likes, groups, chats, profile

        var title: String {
            switch self {
            case .date: "Date"
            case .likes: "Likes"
            case .groups: "Groups"
            case .chats: "Chats"
            case .profile: "Profile"
            }
        }

        var symbol: String {
            switch self {
            case .date: "heart.fill"
            case .likes: "heart.circle.fill"
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
            Tab(AppTab.likes.title, systemImage: AppTab.likes.symbol, value: AppTab.likes) {
                LikesView()
            }
            Tab(AppTab.groups.title, systemImage: AppTab.groups.symbol, value: AppTab.groups) {
                GroupsView()
            }
            Tab(AppTab.chats.title, systemImage: AppTab.chats.symbol, value: AppTab.chats) {
                MatchesListView(model: matches)
            }
            .badge(matches.totalUnread)
            Tab(AppTab.profile.title, systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                ProfileView(session: session)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            // Una sola vez por sesion, y no dentro del mazo: el oyente de
            // `Transaction.updates` tiene que estar puesto desde que entras,
            // estes en la pestana que estes, o una renovacion o una compra
            // hecha fuera de la app no se entera nadie.
            StoreService.shared.start()
            // Si ya diste permiso, el token se renueva sin preguntar nada:
            // APNs lo puede cambiar (restaurar el telefono, reinstalar).
            await push.registerIfAlreadyAllowed()
            await matches.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await matches.load()
                await push.registerIfAlreadyAllowed()
            }
        }
        // El globo del icono cuenta lo mismo que el de la pestana.
        .onChange(of: matches.totalUnread, initial: true) { _, count in
            push.setBadge(count)
        }
        // Un aviso tocado desde fuera de Chats tiene que traerte a Chats.
        .onChange(of: push.pendingMatchID) { _, id in
            if id != nil { selection = .chats }
        }
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
