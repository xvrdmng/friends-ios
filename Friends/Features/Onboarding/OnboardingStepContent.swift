import PhotosUI
import SwiftUI

/// El formulario de cada paso. Separado de la carcasa del wizard para que
/// anadir pasos no toque la navegacion.
struct OnboardingStepContent: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        switch model.step {
        case .name:             nameStep
        case .birthdate:        birthdateStep
        case .gender:           genderStep
        case .datingPreference: preferenceStep
        case .modes:            modesStep
        case .languages:        languagesStep
        case .interests:        interestsStep
        case .aboutYou:         aboutYouStep
        case .photos:           photosStep
        case .bio:              bioStep
        }
    }

    // MARK: - Pasos

    private var nameStep: some View {
        TextField("Tu nombre", text: $model.displayName)
            .textContentType(.givenName)
            .autocorrectionDisabled()
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
    }

    private var birthdateStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Fecha de nacimiento", selection: $model.birthdate,
                       in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))

            Label("\(model.age) años", systemImage: model.age >= 18 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(model.age >= 18 ? .green : .orange)

            if model.age < 18 {
                Text("Tienes que ser mayor de edad para usar Friends.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var genderStep: some View {
        ChipFlow {
            chip("Mujer", "woman", $model.gender)
            chip("Hombre", "man", $model.gender)
            chip("No binario", "non_binary", $model.gender)
            chip("Otro", "other", $model.gender)
        }
    }

    private var preferenceStep: some View {
        ChipFlow {
            chip("Mujeres", "women", $model.datingPreference)
            chip("Hombres", "men", $model.datingPreference)
            chip("Todos", "everyone", $model.datingPreference)
        }
    }

    private var modesStep: some View {
        VStack(spacing: 0) {
            modeRow("Citas", "Buscar pareja o algo casual", $model.modeDating)
            Divider().padding(.leading, 14)
            modeRow("Amistad", "Conocer gente sin romance", $model.modeFriendship)
            Divider().padding(.leading, 14)
            modeRow("Intercambio de idiomas", "Practicar con nativos", $model.modeLanguage)
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(model.selectedInterests.count) seleccionados")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ChipFlow {
                ForEach(model.interests) { interest in
                    ChoiceChip(label: interest.name, emoji: interest.emoji,
                               isSelected: model.selectedInterests.contains(interest.id)) {
                        model.toggleInterest(interest.id)
                    }
                }
            }
        }
    }

    private var aboutYouStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            group("¿Qué buscas?") {
                chip("Algo serio", "serious", $model.relationshipGoal)
                chip("Algo casual", "casual", $model.relationshipGoal)
                chip("Ya veremos", "unsure", $model.relationshipGoal)
            }
            group("Hijos") {
                chip("No tengo", "no_kids", $model.kids)
                chip("Tengo, viven conmigo", "kids_living_with", $model.kids)
                chip("Tengo, no viven conmigo", "kids_not_living_with", $model.kids)
            }
            group("Fumas") {
                chip("No", "smokes_no", $model.smoking)
                chip("A veces", "smokes_sometimes", $model.smoking)
                chip("Sí", "smokes_yes", $model.smoking)
            }
        }
    }

    private var bioStep: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $model.bio)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))

            Text("\(model.bio.count)/500")
                .font(.footnote)
                .foregroundStyle(model.bio.count > 500 ? .red : .secondary)
        }
    }

    private var languagesStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            group("Idioma nativo") {
                ForEach(model.languages) { language in
                    ChoiceChip(label: language.name,
                               isSelected: model.nativeLanguageIds.contains(language.id)) {
                        model.toggleNative(language.id)
                    }
                }
            }

            group("Quiero aprender (opcional)") {
                ForEach(model.languages) { language in
                    ChoiceChip(label: language.name,
                               isSelected: model.learningLevels[language.id] != nil) {
                        model.toggleLearning(language.id)
                    }
                }
            }
        }
    }

    @State private var pickerItems: [PhotosPickerItem] = []

    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(model.photos.count)/\(OnboardingViewModel.maxPhotos) fotos · mínimo \(OnboardingViewModel.minPhotos)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(model.photos) { photo in
                    photoTile(photo)
                }

                if model.isUploading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: .rect(cornerRadius: 12, style: .continuous))
                }

                if model.photos.count < OnboardingViewModel.maxPhotos {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: OnboardingViewModel.maxPhotos - model.photos.count,
                        matching: .images
                    ) {
                        AddPhotoTile()
                    }
                    .disabled(model.isUploading)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await model.upload(data)
                    }
                }
            }
        }
    }

    private func photoTile(_ photo: PhotoItem) -> some View {
        RemoteImage(url: URL(string: photo.thumbUrl))
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipped()
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    Task { await model.removePhoto(photo) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(5)
                .accessibilityLabel("Borrar foto")
            }
    }

    // MARK: - Piezas

    private func chip(_ label: String, _ value: String, _ binding: Binding<String?>) -> some View {
        ChoiceChip(label: label, isSelected: binding.wrappedValue == value) {
            binding.wrappedValue = binding.wrappedValue == value ? nil : value
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ChipFlow { content() }
        }
    }

    private func modeRow(_ title: String, _ detail: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }
}

/// La etiqueta de `PhotosPicker` no esta aislada al main actor, asi que va en
/// su propia vista: con concurrencia estricta, meter aqui un modificador
/// aislado no compila.
private struct AddPhotoTile: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.title)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .background(Color(.secondarySystemFill), in: .rect(cornerRadius: 12, style: .continuous))
    }
}
