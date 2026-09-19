import SwiftUI

/// "¡Es un match!" a pantalla completa, con las dos fotos.
struct MatchCelebrationView: View {
    let match: Match
    let myPhoto: URL?
    let myName: String
    let onMessage: () -> Void
    let onKeepSwiping: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.lazyRose.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("¡ES UN\nMATCH!")
                    .font(.system(size: 56, weight: .black)).multilineTextAlignment(.center)
                    .foregroundStyle(Color.lazyBlack).rotationEffect(.degrees(-4))
                    .scaleEffect(appeared ? 1 : 0.4)

                HStack(spacing: -20) {
                    AvatarView(url: myPhoto, name: myName, size: 130).rotationEffect(.degrees(-8))
                    AvatarView(url: match.other.thumbUrl, name: match.other.displayName, size: 130).rotationEffect(.degrees(8))
                }
                .offset(y: appeared ? 0 : 60).opacity(appeared ? 1 : 0)

                Text("Tú y \(match.other.displayName) se gustaron")
                    .font(.lazySubhead).foregroundStyle(Color.lazyBlack)
                if let group = match.group { Tag(text: group.name, color: .lazyYellow) }

                Spacer()

                VStack(spacing: 14) {
                    Button("Enviar mensaje", action: onMessage)
                        .buttonStyle(LazyButtonStyle(background: .lazyBlack, foreground: .white, fillsWidth: true))
                    Button("Seguir mirando", action: onKeepSwiping)
                        .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack, fillsWidth: true))
                }
                .padding(.horizontal, 30).padding(.bottom, 40)
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true } }
        .accessibilityElement(children: .contain)
    }
}
