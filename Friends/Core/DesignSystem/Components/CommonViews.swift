import SwiftUI

/// Imagen remota con marcador mientras carga. Usa la cache de URLSession.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(systemImage: "photo")
            default:
                placeholder(systemImage: nil)
            }
        }
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color.lazyGray
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 28, weight: .bold)).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

/// Foto redonda con borde sticker; si no hay foto, la inicial.
struct AvatarView: View {
    let url: URL?
    let name: String
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let url {
                RemoteImage(url: url)
            } else {
                ZStack {
                    Color.lazyRose
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.45, weight: .black))
                        .foregroundStyle(Color.lazyBlack)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 3))
    }
}

/// Estado vacio, de error o de "falta algo" con una accion opcional.
struct StateCard: View {
    let emoji: String
    let title: String
    var message: String?
    var color: Color = .white
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji).font(.system(size: 54))
            Text(title)
                .font(.lazySubhead)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.lazyCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(LazyButtonStyle(background: .lazyRose, foreground: .lazyBlack))
                    .padding(.top, 4)
            }
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(26)
        .frame(maxWidth: .infinity)
        .lazyCard(backgroundColor: color)
        .padding(.trailing, 5).padding(.bottom, 5)
    }
}

/// Etiqueta corta en mono (contexto, estado, contadores).
struct Tag: View {
    let text: String
    var color: Color = .white

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.lazyBlack)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .lazyCard(backgroundColor: color, cornerRadius: 10, offset: 2)
            .padding(.trailing, 2).padding(.bottom, 2)
    }
}

/// Aviso breve que desaparece solo.
struct Toast: Equatable, Identifiable {
    let id = UUID()
    let text: String
    var isError = false
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                Text(toast.text)
                    .font(.lazyCaption)
                    .foregroundStyle(Color.lazyBlack)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .lazyCard(backgroundColor: toast.isError ? .lazyNotice : .lazyMint, cornerRadius: 14, offset: 3)
                    .padding(.top, 8).padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.snappy, value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View { modifier(ToastModifier(toast: toast)) }

    /// Espacio para la sombra dura (se dibuja fuera del frame) y para la barra flotante.
    func stickerPadding() -> some View { padding(.trailing, 5).padding(.bottom, 5) }
}

/// Boton circular de cristal (Liquid Glass) para las acciones del mazo.
struct GlassCircleButton: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 64
    var isEnabled = true
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(Color.lazyBlack)
                .frame(width: size, height: size)
                .glassEffect(.regular.tint(tint.opacity(0.75)).interactive(), in: .circle)
                .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Textos de las opciones del servidor (enums) en espanol.
enum Labels {
    static let contexts = ["dating": "Citas", "friendship": "Amistad", "language": "Idiomas", "group": "Grupo"]
    static let categories: [String: (name: String, emoji: String)] = [
        "sports": ("Deporte", "⚽"), "music": ("Música", "🎧"), "food": ("Comida", "🍜"), "travel": ("Viajes", "🧳"),
        "gaming": ("Juegos", "🎮"), "arts": ("Arte", "🎨"), "outdoors": ("Aire libre", "🏕️"),
        "learning": ("Aprender", "📚"), "nightlife": ("Noche", "🌙"), "wellness": ("Bienestar", "🧘")
    ]
    static let kids = ["no_kids": "Sin hijos", "kids_living_with": "Tiene hijos, viven con ella/él",
                       "kids_not_living_with": "Tiene hijos, no viven con ella/él", "kids_private": "Prefiere no decirlo"]
    static let smoking = ["smokes_no": "No fuma", "smokes_sometimes": "Fuma a veces", "smokes_yes": "Fuma"]
    static let drinking = ["drinks_no": "No bebe", "drinks_sometimes": "Bebe a veces", "drinks_yes": "Bebe"]
    static let goal = ["serious": "Algo serio", "casual": "Algo casual", "unsure": "Ya veremos", "friendship_only": "Solo amistad"]
    static let education = ["school": "Escolar", "technical": "Técnica", "university": "Universitaria", "postgraduate": "Posgrado"]

    static func distance(_ km: Int?) -> String? {
        guard let km else { return nil }
        return km == 0 ? "a menos de 1 km" : "a \(km) km"
    }
}
