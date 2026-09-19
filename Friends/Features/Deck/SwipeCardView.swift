import SwiftUI

/// La carta de perfil: foto a pantalla completa con paginador, y el nombre abajo.
/// Tocar el tercio izquierdo/derecho cambia de foto.
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

                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)

                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .overlay(alignment: .top) { pager }
            .overlay { stamps }
            .overlay(alignment: .topTrailing) { verifiedBadge }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in
                guard photos.count > 1 else { return }
                withAnimation(.snappy(duration: 0.15)) {
                    if tap.location.x < geo.size.width / 3 { photoIndex = max(0, photoIndex - 1) }
                    else if tap.location.x > geo.size.width * 2 / 3 { photoIndex = min(photos.count - 1, photoIndex + 1) }
                }
            })
        }
        .background(Color.lazyGray)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.lazyBlack, lineWidth: 3))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.lazyBlack).offset(x: 5, y: 5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.displayName), \(card.age.map(String.init) ?? "")")
    }

    private func photoLayer(size: CGSize) -> some View {
        RemoteImage(url: photos.indices.contains(photoIndex) ? photos[photoIndex].imageURL : nil)
            .frame(width: size.width, height: size.height)
            .clipped()
            .id(photoIndex)
            .transition(.opacity)
    }

    private var pager: some View {
        HStack(spacing: 5) {
            ForEach(photos.indices, id: \.self) { index in
                Capsule()
                    .fill(index == photoIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12)
        .opacity(photos.count > 1 ? 1 : 0)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.displayName).font(.system(size: 34, weight: .black))
                if let age = card.age { Text("\(age)").font(.system(size: 28, weight: .bold)) }
                Spacer()
                Button(action: onInfo) {
                    Image(systemName: "info.circle.fill").font(.system(size: 28))
                }
                .accessibilityLabel("Ver perfil completo")
            }

            HStack(spacing: 8) {
                if let city = card.city { Label(city, systemImage: "mappin.and.ellipse") }
                if let distance = Labels.distance(card.distanceKm) { Text("· \(distance)") }
            }
            .font(.lazyCaption)

            if !card.languages.isEmpty { languageLine }
            else if !card.interests.isEmpty { interestLine }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
    }

    private var languageLine: some View {
        let native = card.languages.filter { $0.kind == "native" }.map(\.name).joined(separator: ", ")
        let learning = card.languages.filter { $0.kind == "learning" }.map { "\($0.name)\($0.level.map { " (\($0.uppercased()))" } ?? "")" }.joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 2) {
            if !native.isEmpty { Text("🗣️ Habla \(native)") }
            if !learning.isEmpty { Text("📖 Aprende \(learning)") }
        }
        .font(.lazyCaption)
    }

    private var interestLine: some View {
        HStack(spacing: 6) {
            ForEach(card.interests.prefix(3)) { interest in
                Text("\(interest.emoji ?? "") \(interest.name)")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(interest.shared ? Color.lazyMint : Color.white.opacity(0.25), in: Capsule())
                    .foregroundStyle(interest.shared ? Color.lazyBlack : .white)
            }
        }
    }

    @ViewBuilder
    private var verifiedBadge: some View {
        if card.verified {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26)).foregroundStyle(Color.lazyCyan)
                .padding(.top, 26).padding(.trailing, 16)
        }
    }

    private var stamps: some View {
        ZStack {
            stamp("LIKE", color: .lazyMint, rotation: -14).opacity(likeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(28)
            stamp("NOPE", color: .lazyRed, rotation: 14).opacity(nopeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(28)
        }
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 38, weight: .black))
            .foregroundStyle(color == .lazyRed ? .white : Color.lazyBlack)
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lazyBlack, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
    }
}

/// Envuelve una carta con el gesto de arrastre. Al soltar decide con `SwipeMath`.
struct DraggableCard: View {
    let card: DeckCard
    /// Los botones piden la decision por aqui, para que la carta vuele igual que con el dedo.
    @Binding var command: DeckViewModel.Decision?
    let onDecision: (DeckViewModel.Decision) -> Void
    let onInfo: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isFlying = false

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
        withAnimation(.easeIn(duration: 0.22)) { offset = target }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            onDecision(decision)
        }
    }
}
