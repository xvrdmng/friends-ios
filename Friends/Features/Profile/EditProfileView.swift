import SwiftUI

/// Editar el perfil: lo mismo que pide el wizard, menos lo que no se puede
/// cambiar (la fecha de nacimiento fija la edad 18+).
struct EditProfileView: View {
    var api: any APIService = APIClient.shared
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var bio = ""
    @State private var occupation = ""
    @State private var heightCm: Int?
    @State private var education: String?
    @State private var relationshipGoal: String?
    @State private var kids: String?
    @State private var smoking: String?
    @State private var drinking: String?
    @State private var modeDating = true
    @State private var modeFriendship = true
    @State private var modeLanguage = false
    @State private var selectedInterests: Set<String> = []
    @State private var interests: [InterestItem] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var toast: Toast?

    private static let maxBio = 500

    var body: some View {
        NavigationStack {
            ZStack {
                DoodleBackground()
                if isLoading { ProgressView() } else { form }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Guardando…" : "Guardar") { Task { await save() } }
                        .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .toast($toast)
        }
        .task { await load() }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                field("Nombre") {
                    TextField("Tu nombre", text: $displayName).font(.lazyBody)
                }
                modesSection
                field("Bio") {
                    TextField("Cuéntate en pocas líneas", text: $bio, axis: .vertical)
                        .font(.lazyBody).lineLimit(3...8)
                        .onChange(of: bio) { _, new in if new.count > Self.maxBio { bio = String(new.prefix(Self.maxBio)) } }
                }
                Text("\(bio.count)/\(Self.maxBio)").font(.lazyMono).foregroundStyle(.secondary)
                field("A qué te dedicas") {
                    TextField("Opcional", text: $occupation).font(.lazyBody)
                }
                heightSection
                chips("Estudios", Labels.education, $education)
                chips("Qué buscas", Labels.goal, $relationshipGoal)
                chips("Hijos", Labels.kids, $kids)
                chips("Fumas", Labels.smoking, $smoking)
                chips("Bebes", Labels.drinking, $drinking)
                interestsSection
            }
            .padding(22).padding(.bottom, 30)
        }
    }

    // MARK: - Secciones

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.lazyMono).foregroundStyle(.secondary)
            content()
                .foregroundStyle(Color.lazyBlack)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .lazyCard().stickerPadding()
        }
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A QUÉ VIENES").font(.lazyMono).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ChoiceChip(label: "Citas", emoji: "❤️", isSelected: modeDating) { modeDating.toggle() }
                ChoiceChip(label: "Amistad", emoji: "🤝", selectedColor: .lazyMint, isSelected: modeFriendship) { modeFriendship.toggle() }
                ChoiceChip(label: "Idiomas", emoji: "🗣️", selectedColor: .lazyYellow, isSelected: modeLanguage) { modeLanguage.toggle() }
            }
            if !modeDating && !modeFriendship && !modeLanguage {
                Text("Elige al menos uno, si no el mazo se queda vacío.")
                    .font(.lazyCaption).foregroundStyle(Color.lazyRed)
            }
        }
    }

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ALTURA").font(.lazyMono).foregroundStyle(.secondary)
                Spacer()
                Text(heightCm.map { "\($0) cm" } ?? "Sin decir").font(.lazyMono).foregroundStyle(Color.lazyBlack)
                if heightCm != nil {
                    Button("Quitar") { heightCm = nil }.font(.lazyMono).foregroundStyle(Color.lazyRed)
                }
            }
            Slider(value: Binding(get: { Double(heightCm ?? 170) }, set: { heightCm = Int($0) }),
                   in: 130...220, step: 1)
                .tint(Color.lazyRose)
        }
    }

    private func chips(_ title: String, _ options: [String: String], _ selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.lazyMono).foregroundStyle(.secondary)
            ChipFlow(spacing: 8) {
                ForEach(options.keys.sorted(), id: \.self) { key in
                    ChoiceChip(label: options[key] ?? key, isSelected: selection.wrappedValue == key) {
                        selection.wrappedValue = selection.wrappedValue == key ? nil : key
                    }
                }
            }
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INTERESES · \(selectedInterests.count)").font(.lazyMono).foregroundStyle(.secondary)
            if selectedInterests.count < 3 {
                Text("Elige al menos 3.").font(.lazyCaption).foregroundStyle(Color.lazyRed)
            }
            ForEach(Array(Labels.categories.keys).sorted(), id: \.self) { category in
                let items = interests.filter { $0.category == category }
                if !items.isEmpty {
                    Text("\(Labels.categories[category]?.emoji ?? "") \(Labels.categories[category]?.name ?? category)")
                        .font(.lazyCaption).foregroundStyle(Color.lazyBlack)
                    ChipFlow(spacing: 8) {
                        ForEach(items) { interest in
                            ChoiceChip(label: interest.name, emoji: interest.emoji,
                                       isSelected: selectedInterests.contains(interest.id)) {
                                if selectedInterests.contains(interest.id) { selectedInterests.remove(interest.id) }
                                else { selectedInterests.insert(interest.id) }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Datos

    private func load() async {
        defer { isLoading = false }
        if let response: InterestsResponse = try? await api.send(.interests) { interests = response.interests }
        guard let me: MeResponse = try? await api.send(.me) else { return }

        displayName = me.profile?.displayName ?? ""
        bio = me.profile?.bio ?? ""
        occupation = me.profile?.occupation ?? ""
        heightCm = me.profile?.heightCm
        education = me.profile?.education
        relationshipGoal = me.profile?.relationshipGoal
        kids = me.profile?.kids
        smoking = me.profile?.smoking
        drinking = me.profile?.drinking
        modeDating = me.profile?.modeDating ?? true
        modeFriendship = me.profile?.modeFriendship ?? true
        modeLanguage = me.profile?.modeLanguage ?? false
        selectedInterests = Set(me.interestIds ?? [])
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var payload = OnboardingPayload()
        payload.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.occupation = occupation.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.heightCm = heightCm
        payload.education = education
        payload.relationshipGoal = relationshipGoal
        payload.kids = kids
        payload.smoking = smoking
        payload.drinking = drinking
        payload.modeDating = modeDating
        payload.modeFriendship = modeFriendship
        payload.modeLanguage = modeLanguage

        do {
            // Los campos van por PATCH /me; los intereses, por el mismo endpoint
            // del wizard, que es el unico que los guarda.
            try await api.send(.updateMe, body: payload)
            var interestsPayload = OnboardingPayload()
            interestsPayload.interestIds = Array(selectedInterests)
            try await api.send(.onboarding, body: interestsPayload)
            onSaved()
            dismiss()
        } catch APIError.server(_, let message) {
            toast = Toast(text: message, isError: true)
        } catch {
            toast = Toast(text: "No se pudieron guardar los cambios", isError: true)
        }
    }
}
