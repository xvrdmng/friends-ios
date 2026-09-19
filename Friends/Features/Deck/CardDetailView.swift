import SwiftUI

/// El perfil completo de una carta: todas las fotos, sobre mi, intereses y datos.
struct CardDetailView: View {
    let card: DeckCard
    var onReport: () -> Void = {}
    var onBlock: () -> Void = {}
    /// En la vista previa del perfil propio no hay a quien reportar.
    var showsSafetyActions = true

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TabView(selection: $page) {
                        ForEach(Array(card.photos.enumerated()), id: \.element.id) { index, photo in
                            RemoteImage(url: photo.imageURL).tag(index).clipped()
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 460)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.lazyBlack, lineWidth: 3))
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.lazyBlack).offset(x: 5, y: 5))
                    .padding(.trailing, 5).padding(.bottom, 5)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(card.displayName).font(.lazyHeading)
                            if let age = card.age { Text("\(age)").font(.system(size: 26, weight: .bold)) }
                            if card.verified { Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.lazyCyan) }
                        }
                        if let occupation = card.occupation { Text(occupation).font(.lazyBody).foregroundStyle(.secondary) }
                        HStack(spacing: 8) {
                            if let city = card.city { Label(city, systemImage: "mappin.and.ellipse") }
                            if let distance = Labels.distance(card.distanceKm) { Text("· \(distance)") }
                        }
                        .font(.lazyCaption).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Color.lazyBlack)

                    if let bio = card.bio, !bio.isEmpty {
                        section("Sobre mí") { Text(bio).font(.lazyBody) }
                    }

                    if !card.languages.isEmpty {
                        section("Idiomas") {
                            ForEach(card.languages, id: \.code) { language in
                                Text("\(language.kind == "native" ? "🗣️ Nativo" : "📖 Aprende"): \(language.name)\(language.level.map { " · \($0.uppercased())" } ?? "")")
                                    .font(.lazyBody)
                            }
                        }
                    }

                    if !card.interests.isEmpty {
                        section("Intereses") {
                            if card.sharedInterestCount > 0 {
                                Text("\(card.sharedInterestCount) en común").font(.lazyMono).foregroundStyle(.secondary)
                            }
                            ChipFlow {
                                ForEach(card.interests) { interest in
                                    Text("\(interest.emoji ?? "") \(interest.name)")
                                        .font(.system(size: 15, weight: .bold))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .lazyCard(backgroundColor: interest.shared ? .lazyMint : .white, cornerRadius: 14, offset: 2)
                                        .padding(.trailing, 2).padding(.bottom, 2)
                                }
                            }
                        }
                    }

                    let facts = facts
                    if !facts.isEmpty {
                        section("Datos") {
                            ChipFlow { ForEach(facts, id: \.self) { Tag(text: $0, color: .white) } }
                        }
                    }

                    if showsSafetyActions {
                        HStack(spacing: 12) {
                            Button("Reportar", action: onReport)
                                .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack, fillsWidth: true))
                            Button("Bloquear", action: onBlock)
                                .buttonStyle(LazyButtonStyle(background: .lazyNotice, foreground: .lazyBlack, fillsWidth: true))
                        }
                        .padding(.trailing, 5).padding(.top, 8)
                    }
                }
                .padding(22).padding(.bottom, 30)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 40, height: 40).glassEffect(.regular, in: .circle)
            }
            .padding(16).accessibilityLabel("Cerrar")
        }
    }

    private var facts: [String] {
        [card.relationshipGoal.flatMap { Labels.goal[$0] }, card.kids.flatMap { Labels.kids[$0] },
         card.smoking.flatMap { Labels.smoking[$0] }, card.drinking.flatMap { Labels.drinking[$0] },
         card.education.flatMap { Labels.education[$0] }, card.heightCm.map { "\($0) cm" }].compactMap { $0 }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.lazyMono).foregroundStyle(.secondary)
            content()
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .lazyCard().padding(.trailing, 5).padding(.bottom, 5)
    }
}
