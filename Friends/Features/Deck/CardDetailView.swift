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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photos
                    heading
                    if let bio = card.bio, !bio.isEmpty {
                        section("Sobre mí") { Text(bio) }
                    }
                    if !card.languages.isEmpty { languages }
                    if !card.interests.isEmpty { interests }
                    if !facts.isEmpty { section("Datos") { factList } }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(card.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
                if showsSafetyActions {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Reportar", systemImage: "flag", action: onReport)
                            Button("Bloquear", systemImage: "hand.raised", role: .destructive, action: onBlock)
                        } label: {
                            Label("Más opciones", systemImage: "ellipsis")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Secciones

    private var photos: some View {
        TabView(selection: $page) {
            ForEach(Array(card.photos.enumerated()), id: \.element.id) { index, photo in
                RemoteImage(url: photo.imageURL).tag(index).clipped()
            }
        }
        .tabViewStyle(.page)
        .frame(height: 460)
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .accessibilityLabel("Fotos de \(card.displayName)")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(card.displayName).font(.title.weight(.bold))
                if let age = card.age { Text(age.formatted()).font(.title2) }
                if card.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Perfil verificado")
                }
            }
            if let occupation = card.occupation {
                Text(occupation).font(.body).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if let city = card.city { Label(city, systemImage: "mappin.and.ellipse") }
                if let distance = Labels.distance(card.distanceKm) { Text("· \(distance)") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var languages: some View {
        section("Idiomas") {
            ForEach(card.languages, id: \.code) { language in
                Label {
                    Text("\(language.name)\(language.level.map { " · \($0.uppercased())" } ?? "")")
                } icon: {
                    Image(systemName: language.kind == "native" ? "quote.bubble" : "book")
                }
            }
        }
    }

    private var interests: some View {
        section("Intereses") {
            if card.sharedInterestCount > 0 {
                Text("\(card.sharedInterestCount) en común")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
            }
            ChipFlow {
                ForEach(card.interests) { interest in
                    Tag(text: "\(interest.emoji ?? "") \(interest.name)",
                        tint: interest.shared ? Color.accentColor : .secondary)
                }
            }
        }
    }

    private var factList: some View {
        ChipFlow {
            ForEach(facts, id: \.self) { Tag(text: $0) }
        }
    }

    private var facts: [String] {
        [card.relationshipGoal.flatMap { Labels.goal[$0] }, card.kids.flatMap { Labels.kids[$0] },
         card.smoking.flatMap { Labels.smoking[$0] }, card.drinking.flatMap { Labels.drinking[$0] },
         card.education.flatMap { Labels.education[$0] }, card.heightCm.map { "\($0) cm" }].compactMap { $0 }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
                .font(.body)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }
}
