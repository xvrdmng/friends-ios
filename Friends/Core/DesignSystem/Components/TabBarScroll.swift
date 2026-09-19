import SwiftUI

/// Hace que un ScrollView encoja o expanda la barra flotante al hacer scroll.
private struct TabBarScrollModifier: ViewModifier {
    @Environment(TabBarState.self) private var bar

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { old, new in
            withAnimation(.snappy) { bar.scrolled(from: old, to: new) }
        }
    }
}

extension View {
    func drivesTabBar() -> some View { modifier(TabBarScrollModifier()) }
}
