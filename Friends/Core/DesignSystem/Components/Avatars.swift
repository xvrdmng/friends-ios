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
            Color(.secondarySystemFill)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
            }
        }
    }
}

/// Foto de perfil redonda; si no hay foto, la inicial sobre el color de acento.
struct AvatarView: View {
    let url: URL?
    let name: String
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let url {
                RemoteImage(url: url)
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        // Separa la foto del fondo sin dibujar un borde opaco encima.
        .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
    }

    private var initial: some View {
        ZStack {
            Color.accentColor.opacity(0.18)
            Text(String(name.prefix(1)).uppercased())
                // El diametro lo fija quien usa el avatar, asi que la inicial
                // escala con el circulo y no con el cuerpo de texto.
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
    }
}
