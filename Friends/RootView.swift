import SwiftUI

/// Estado compartido de la barra flotante: las pantallas con scroll lo
/// actualizan y la barra se encoge o se expande.
@MainActor
@Observable
final class TabBarState {
    var isMinimized = false

    /// Bajar encoge la barra, subir (o volver arriba del todo) la expande.
    func scrolled(from old: CGFloat, to new: CGFloat) {
        let delta = new - old
        if new <= 10 { isMinimized = false }
        else if delta > 6 { isMinimized = true }
        else if delta < -6 { isMinimized = false }
    }
}

/// Navegación principal: barra flotante de cristal (Liquid Glass) con la
/// pestaña activa en rosa. Es propia, no la de TabView, porque la nativa no
/// deja cambiar el color de la seleccion.
struct RootView: View {
    let session: SessionViewModel

    private enum Tab: CaseIterable {
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

        var icon: String {
            switch self {
            case .date: "heart.fill"
            case .friends: "person.2.fill"
            case .groups: "square.grid.2x2.fill"
            case .chats: "bubble.left.fill"
            case .profile: "person.crop.circle.fill"
            }
        }
    }

    @State private var selection: Tab = .date
    @State private var bar = TabBarState()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .date:    DeckView(context: .dating)
                case .friends: DeckView(context: .friendship)
                case .groups:  GroupsView()
                case .chats:   MatchesListView()
                case .profile: ProfileView(session: session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .environment(bar)
        .onChange(of: selection) { bar.isMinimized = false }
    }

    @ViewBuilder
    private var tabBar: some View {
        if bar.isMinimized {
            HStack {
                Button {
                    withAnimation(.snappy) { bar.isMinimized = false }
                } label: {
                    Image(systemName: selection.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.lazyBlack)
                        .frame(width: 52, height: 52)
                        .background(Color.lazyRose, in: Circle())
                        .padding(6)
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selection.title)
                Spacer()
            }
            .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
        } else {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let selected = tab == selection
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selection = tab }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 21, weight: .bold))
                            Text(tab.title)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.lazyBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule().fill(Color.lazyRose)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .glassEffect(.regular, in: .capsule)
            .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            DoodleBackground()
            Text("FRIENDS")
                .font(.lazyDisplay)
                .kerning(4)
                .foregroundStyle(Color.lazyBlack)
        }
    }
}
