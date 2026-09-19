import SwiftUI

/// "¡Es un match!" a pantalla completa, con las dos fotos.
struct MatchCelebrationView: View {
    let match: Match
    let myPhoto: URL?
    let myName: String
    let onMessage: () -> Void
    let onKeepSwiping: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("¡Es un match!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .scaleEffect(reduceMotion || appeared ? 1 : 0.6)

                HStack(spacing: -20) {
                    AvatarView(url: myPhoto, name: myName, size: 120)
                    AvatarView(url: match.other.thumbUrl, name: match.other.displayName, size: 120)
                }
                .opacity(reduceMotion || appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Tú y \(match.other.displayName) se gustaron")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                    if let group = match.group {
                        Tag(text: group.name, tint: Color.accentColor)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button("Enviar mensaje", action: onMessage)
                        .buttonStyle(.glassProminent)
                    Button("Seguir mirando", action: onKeepSwiping)
                        .buttonStyle(.glass)
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Es un match con \(match.other.displayName)")
    }
}
