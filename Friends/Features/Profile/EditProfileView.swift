import SwiftUI

/// Editar el perfil: lo mismo que pide el wizard, menos lo que no se puede
/// cambiar (la fecha de nacimiento fija la edad 18+ y el servidor la bloquea).
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
    @State private var loadFailed = false
    @State private var isSaving = false
    @State private var error: AlertMessage?

    private static let maxBio = 500

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadFailed {
                    // Sin esto el formulario salia VACIO y guardar borraba de
                    // verdad la bio, los intereses y el resto: lo que no se
                    // pudo leer se mandaba de vuelta como si estuviera en blanco.
                    ContentUnavailableView {
                        Label("No pudimos cargar tu perfil", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Revisa tu conexión. No editamos nada hasta poder leer lo que ya tienes.")
                    } actions: {
                        Button("Reintentar") { Task { await load() } }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    form
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                if !loadFailed {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") { Task { await save() } }
                            .disabled(isSaving || isLoading
                                      || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .errorAlert($error)
            .disabled(isSaving)
        }
        .task { await load() }
    }

    private var form: some View {
        Form {
            Section("Nombre") {
                TextField("Tu nombre", text: $displayName)
            }

            Section {
                Toggle("Citas", isOn: $modeDating)
                Toggle("Amistad", isOn: $modeFriendship)
                Toggle("Idiomas", isOn: $modeLanguage)
            } header: {
                Text("A qué vienes")
            } footer: {
                if !modeDating && !modeFriendship && !modeLanguage {
                    Text("Elige al menos uno, si no el mazo se queda vacío.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                TextField("Cuéntate en pocas líneas", text: $bio, axis: .vertical)
                    .lineLimit(3...8)
                    .onChange(of: bio) { _, new in
                        if new.count > Self.maxBio { bio = String(new.prefix(Self.maxBio)) }
                    }
            } header: {
                Text("Bio")
            } footer: {
                Text("\(bio.count)/\(Self.maxBio)")
            }

            Section("A qué te dedicas") {
                TextField("Opcional", text: $occupation)
            }

            heightSection

            chipSection("Estudios", Labels.education, $education)
            chipSection("Qué buscas", Labels.goal, $relationshipGoal)
            chipSection("Hijos", Labels.kids, $kids)
            chipSection("Fumas", Labels.smoking, $smoking)
            chipSection("Bebes", Labels.drinking, $drinking)

            interestsSection
        }
    }

    // MARK: - Secciones

    private var heightSection: some View {
        Section {
            LabeledContent("Altura") {
                HStack(spacing: 12) {
                    Text(heightCm.map { "\($0) cm" } ?? "Sin decir")
                    if heightCm != nil {
                        Button("Quitar") { heightCm = nil }.font(.footnote)
                    }
                }
            }
            Slider(value: Binding(get: { Double(heightCm ?? 170) }, set: { heightCm = Int($0) }),
                   in: 130...220, step: 1)
                .accessibilityLabel("Altura en centímetros")
                .accessibilityValue(heightCm.map { "\($0) centímetros" } ?? "sin decir")
        }
    }

    private func chipSection(_ title: String, _ options: [String: String],
                             _ selection: Binding<String?>) -> some View {
        Section(title) {
            ChipFlow {
                ForEach(options.keys.sorted(), id: \.self) { key in
                    ChoiceChip(label: options[key] ?? key, isSelected: selection.wrappedValue == key) {
                        selection.wrappedValue = selection.wrappedValue == key ? nil : key
                    }
                }
            }
        }
    }

    private var interestsSection: some View {
        Section {
            ForEach(Array(Labels.categories.keys).sorted(), id: \.self) { category in
                let items = interests.filter { $0.category == category }
                if !items.isEmpty {
                    Text("\(Labels.categories[category]?.emoji ?? "") \(Labels.categories[category]?.name ?? category)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ChipFlow {
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
        } header: {
            Text("Intereses · \(selectedInterests.count)")
        } footer: {
            if selectedInterests.count < 3 {
                Text("Elige al menos 3.").foregroundStyle(.red)
            }
        }
    }

    // MARK: - Datos

    private func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        if let response: InterestsResponse = try? await api.send(.interests) { interests = response.interests }
        guard let me: MeResponse = try? await api.send(.me) else {
            loadFailed = true
            return
        }

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
            // Los campos van por PATCH /me; los intereses, por el endpoint del
            // wizard, que es el unico que los persiste (`apply_interests!`).
            // Si se unifican, los intereses se pierden en silencio.
            try await api.send(.updateMe, body: payload)
            var interestsPayload = OnboardingPayload()
            interestsPayload.interestIds = Array(selectedInterests)
            try await api.send(.onboarding, body: interestsPayload)
            onSaved()
            dismiss()
        } catch APIError.server(_, let message) {
            error = AlertMessage("No se pudieron guardar los cambios", message: message)
        } catch {
            self.error = AlertMessage("No se pudieron guardar los cambios")
        }
    }
}
