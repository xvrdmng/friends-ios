import SwiftUI

/// "Ver cómo te ven": monta una carta del mazo con los datos propios y la
/// muestra con la misma pantalla que los demas perfiles.
struct ProfilePreviewView: View {
    let me: MeResponse?
    var api: any APIService = APIClient.shared

    @State private var card: DeckCard?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            DoodleBackground()
            if let card {
                CardDetailView(card: card, showsSafetyActions: false)
            } else if isLoading {
                ProgressView()
            } else {
                StateCard(emoji: "🫥", title: "Aún no hay nada que enseñar",
                          message: "Completa tu perfil y sube fotos para verte como te ven.", color: .lazyNotice)
                    .padding(22)
            }
        }
        .task { await build() }
    }

    private func build() async {
        defer { isLoading = false }
        guard let me, let profile = me.profile else { return }

        async let interestsCatalog: InterestsResponse? = try? api.send(.interests)
        async let languagesCatalog: LanguagesResponse? = try? api.send(.languages)
        let (catalog, languages) = await (interestsCatalog, languagesCatalog)

        let selected = Set(me.interestIds ?? [])
        let cardInterests = (catalog?.interests ?? [])
            .filter { selected.contains($0.id) }
            .map { CardInterest(id: $0.id, slug: $0.slug, name: $0.name, emoji: $0.emoji, shared: false) }

        let byID = Dictionary(uniqueKeysWithValues: (languages?.languages ?? []).map { ($0.id, $0) })
        let cardLanguages = (me.languages ?? []).compactMap { entry -> CardLanguage? in
            guard let language = byID[entry.languageId] else { return nil }
            return CardLanguage(code: language.code, name: language.name, kind: entry.kind, level: entry.level)
        }

        card = DeckCard(
            userId: me.user.id,
            displayName: profile.displayName ?? "Tú",
            age: profile.age,
            bio: profile.bio,
            occupation: profile.occupation,
            city: profile.city,
            distanceKm: nil,
            gender: profile.gender,
            heightCm: profile.heightCm,
            kids: profile.kids,
            smoking: profile.smoking,
            drinking: profile.drinking,
            relationshipGoal: profile.relationshipGoal,
            education: profile.education,
            verified: false,
            sharedInterestCount: 0,
            interests: cardInterests,
            languages: cardLanguages,
            photos: me.photos ?? []
        )
    }
}
