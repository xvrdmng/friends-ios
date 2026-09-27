import SwiftUI

/// La carta de perfil: foto a pantalla completa con paginador y el nombre
/// abajo. Tocar el tercio izquierdo/derecho cambia de foto.
struct ProfileCardView: View {
    let card: DeckCard
    var likeOpacity: Double = 0
    var nopeOpacity: Double = 0
    var onInfo: () -> Void = {}

    @State private var photoIndex = 0

    private var photos: [PhotoItem] { card.photos }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                photoLayer(size: geo.size)

                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)

                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .overlay(alignment: .top) { pager }
            .overlay { stamps }
            .overlay(alignment: .topTrailing) { verifiedBadge }
            .contentShape(.rect)
            .gesture(SpatialTapGesture().onEnded { tap in
                guard photos.count > 1 else { return }
                withAnimation(.snappy(duration: 0.15)) {
                    if tap.location.x < geo.size.width / 3 { photoIndex = max(0, photoIndex - 1) }
                    else if tap.location.x > geo.size.width * 2 / 3 { photoIndex = min(photos.count - 1, photoIndex + 1) }
                }
            })
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Desliza a la derecha para dar like, a la izquierda para pasar")
    }

    private var accessibilityDescription: String {
        [card.displayName, card.age.map { "\($0) años" }, card.city, Labels.distance(card.distanceKm)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func photoLayer(size: CGSize) -> some View {
        RemoteImage(url: photos.indices.contains(photoIndex) ? photos[photoIndex].imageURL : nil)
            .frame(width: size.width, height: size.height)
            .clipped()
            .id(photoIndex)
            .transition(.opacity)
    }

    private var pager: some View {
        HStack(spacing: 4) {
            ForEach(photos.indices, id: \.self) { index in
                Capsule()
                    .fill(index == photoIndex ? .white : Color.white.opacity(0.4))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12)
        .opacity(photos.count > 1 ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.displayName)
                    .font(.largeTitle.weight(.bold))
                if let age = card.age {
                    Text(age.formatted())
                        .font(.title2)
                }
                Spacer()
                Button(action: onInfo) {
                    Image(systemName: "info.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ver perfil completo de \(card.displayName)")
            }

            HStack(spacing: 6) {
                if let city = card.city { Label(city, systemImage: "mappin.and.ellipse") }
                if let distance = Labels.distance(card.distanceKm) { Text("· \(distance)") }
            }
            .font(.subheadline)

            if !card.languages.isEmpty { languageLine }
            else if !card.interests.isEmpty { interestLine }
        }
        .foregroundStyle(.white)
        // El texto cae sobre una foto arbitraria: la sombra es lo que garantiza
        // que se lea sobre una zona clara.
        .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
    }

    private var languageLine: some View {
        let native = card.languages.filter { $0.kind == "native" }.map(\.name).joined(separator: ", ")
        let learning = card.languages.filter { $0.kind == "learning" }
            .map(\.name)
            .joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 2) {
            if !native.isEmpty { Label("Habla \(native)", systemImage: "quote.bubble") }
            if !learning.isEmpty { Label("Aprende \(learning)", systemImage: "book") }
        }
        .font(.subheadline)
    }

    private var interestLine: some View {
        HStack(spacing: 6) {
            ForEach(card.interests.prefix(3)) { interest in
                Text("\(interest.emoji ?? "") \(interest.name)")
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: .capsule)
                    .overlay(
                        Capsule().strokeBorder(
                            interest.shared ? Color.accentColor : .clear,
                            lineWidth: 1
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private var verifiedBadge: some View {
        if card.verified {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .padding(.top, 26).padding(.trailing, 16)
                .accessibilityLabel("Perfil verificado")
        }
    }

    private var stamps: some View {
        ZStack {
            stamp("LIKE", tint: .green, rotation: -14).opacity(likeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(28)
            stamp("NOPE", tint: .red, rotation: 14).opacity(nopeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(28)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func stamp(_ text: String, tint: Color, rotation: Double) -> some View {
        Text(text)
            .font(.largeTitle.weight(.heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint, lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
    }
}

/// Envuelve una carta con el gesto de arrastre. Al soltar decide con `SwipeMath`.
struct DraggableCard: View {
    let card: DeckCard
    /// Los botones piden la decision por aqui, para que la carta vuele igual
    /// que con el dedo.
    @Binding var command: DeckViewModel.Decision?
    let onDecision: (DeckViewModel.Decision) -> Void
    let onInfo: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isFlying = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ProfileCardView(
            card: card,
            likeOpacity: SwipeMath.stampOpacity(forWidth: offset.width, positive: true),
            nopeOpacity: SwipeMath.stampOpacity(forWidth: offset.width, positive: false),
            onInfo: onInfo
        )
        .offset(offset)
        .rotationEffect(.degrees(SwipeMath.rotation(forWidth: offset.width)), anchor: .bottom)
        .gesture(
            DragGesture()
                .onChanged { offset = $0.translation }
                .onEnded { value in
                    switch SwipeMath.outcome(translation: value.translation, predicted: value.predictedEndTranslation) {
                    case .like:      fly(.like, toward: CGSize(width: 700, height: value.translation.height))
                    case .pass:      fly(.pass, toward: CGSize(width: -700, height: value.translation.height))
                    case .superlike: fly(.superlike, toward: CGSize(width: 0, height: -900))
                    case .none:      withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                    }
                }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isFlying)
        // Con VoiceOver no hay gesto de arrastre util: las mismas decisiones se
        // ofrecen como acciones del rotor.
        .accessibilityActions {
            Button("Me gusta") { fly(.like, toward: CGSize(width: 700, height: -40)) }
            Button("No me interesa") { fly(.pass, toward: CGSize(width: -700, height: -40)) }
            Button("Ver perfil completo", action: onInfo)
        }
        .onChange(of: command) { _, requested in
            guard let requested, !isFlying else { return }
            command = nil
            switch requested {
            case .like:      fly(.like, toward: CGSize(width: 700, height: -40))
            case .pass:      fly(.pass, toward: CGSize(width: -700, height: -40))
            case .superlike: fly(.superlike, toward: CGSize(width: 0, height: -900))
            }
        }
    }

    private func fly(_ decision: DeckViewModel.Decision, toward target: CGSize) {
        isFlying = true
        // Con Reducir movimiento la carta se desvanece en vez de salir volando.
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.15)) { offset = .zero }
            onDecision(decision)
            return
        }
        withAnimation(.easeIn(duration: 0.22)) { offset = target }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            onDecision(decision)
        }
    }
}
