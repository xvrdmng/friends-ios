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
            .font(.lazySubhead)
            .textContentType(.givenName)
            .autocorrectionDisabled()
            .foregroundStyle(Color.lazyBlack)
            .padding(14)
            .lazyCard(cornerRadius: 16)
    }

    private var birthdateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            DatePicker(
                "Fecha de nacimiento",
                selection: $model.birthdate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .lazyCard(cornerRadius: 16)

            Text("\(model.age) ANOS")
                .font(.lazyMono)
                .foregroundStyle(Color.lazyBlack)
                .padding(10)
                .lazyCard(backgroundColor: model.age >= 18 ? .lazyMint : .lazyNotice,
                          cornerRadius: 14, offset: 3)
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
        VStack(spacing: 12) {
            modeRow("Citas", "Buscar pareja o algo casual", $model.modeDating)
            modeRow("Amistad", "Conocer gente sin romance", $model.modeFriendship)
            modeRow("Intercambio de idiomas", "Practicar con nativos", $model.modeLanguage)
        }
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(model.selectedInterests.count) SELECCIONADOS")
                .font(.lazyMono)
                .kerning(1.2)
                .foregroundStyle(Color.lazyBlack.opacity(0.65))

            ChipFlow {
                ForEach(model.interests) { interest in
                    ChoiceChip(
                        label: interest.name,
                        emoji: interest.emoji,
                        selectedColor: .lazyRose,
                        isSelected: model.selectedInterests.contains(interest.id)
                    ) {
                        model.toggleInterest(interest.id)
                    }
                }
            }
        }
    }

    private var aboutYouStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            group("¿Que buscas?") {
                chip("Algo serio", "serious", $model.relationshipGoal)
                chip("Algo casual", "casual", $model.relationshipGoal)
                chip("Ya veremos", "unsure", $model.relationshipGoal)
            }
            group("Hijos") {
                chip("No tengo", "no_kids", $model.kids, color: .lazyMint)
                chip("Tengo, viven conmigo", "kids_living_with", $model.kids, color: .lazyMint)
                chip("Tengo, no viven conmigo", "kids_not_living_with", $model.kids, color: .lazyMint)
            }
            group("Fumas") {
                chip("No", "smokes_no", $model.smoking, color: .lazyYellow)
                chip("A veces", "smokes_sometimes", $model.smoking, color: .lazyYellow)
                chip("Si", "smokes_yes", $model.smoking, color: .lazyYellow)
            }
        }
    }

    private var bioStep: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $model.bio)
                .font(.lazyBody)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Color.lazyBlack)
                .frame(minHeight: 160)
                .padding(10)
                .lazyCard(cornerRadius: 16)

            Text("\(model.bio.count)/500")
                .font(.lazyMono)
                .foregroundStyle(model.bio.count > 500 ? Color.lazyRed : Color.lazyBlack.opacity(0.65))
        }
    }

    private var languagesStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            group("Idioma nativo") {
                ForEach(model.languages) { language in
                    ChoiceChip(
                        label: language.name,
                        selectedColor: .lazyMint,
                        isSelected: model.nativeLanguageIds.contains(language.id)
                    ) { model.toggleNative(language.id) }
                }
            }

            group("Quiero aprender (opcional)") {
                ForEach(model.languages) { language in
                    ChoiceChip(
                        label: language.name,
                        selectedColor: .lazyYellow,
                        isSelected: model.learningLevels[language.id] != nil
                    ) { model.toggleLearning(language.id) }
                }
            }

            ForEach(model.languages.filter { model.learningLevels[$0.id] != nil }) { language in
                levelRow(language)
            }
        }
    }

    private func levelRow(_ language: LanguageItem) -> some View {
        HStack {
            Text("\(language.name.uppercased()) · NIVEL")
                .font(.lazyMono)
            Spacer()
            Picker("Nivel", selection: Binding(
                get: { model.learningLevels[language.id] ?? "a1" },
                set: { model.learningLevels[language.id] = $0 }
            )) {
                ForEach(["a1", "a2", "b1", "b2", "c1", "c2"], id: \.self) { Text($0.uppercased()).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Color.lazyBlack)
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .lazyCard(backgroundColor: .lazyYellow, cornerRadius: 16, offset: 3)
    }

    @State private var pickerItems: [PhotosPickerItem] = []

    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(model.photos.count)/\(OnboardingViewModel.maxPhotos) FOTOS · MINIMO \(OnboardingViewModel.minPhotos)")
                .font(.lazyMono)
                .kerning(1)
                .foregroundStyle(Color.lazyBlack.opacity(0.65))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(model.photos) { photo in
                    photoTile(photo)
                }

                if model.isUploading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .lazyCard(backgroundColor: .white, cornerRadius: 14, offset: 3)
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
            .padding(.trailing, 3)
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
        AsyncImage(url: URL(string: photo.thumbUrl)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .failure: Image(systemName: "photo").font(.title).foregroundStyle(Color.lazyBlack.opacity(0.4))
            default: ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3 / 4, contentMode: .fit)
        .background(Color.white)
        .lazyCard(backgroundColor: .white, cornerRadius: 14, offset: 3)
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await model.removePhoto(photo) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.lazyRed, in: Circle())
                    .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .padding(5)
        }
    }

    // MARK: - Piezas

    private func chip(_ label: String, _ value: String, _ binding: Binding<String?>,
                      color: Color = .lazyRose) -> some View {
        ChoiceChip(label: label, selectedColor: color, isSelected: binding.wrappedValue == value) {
            binding.wrappedValue = binding.wrappedValue == value ? nil : value
        }
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.lazyMono)
                .kerning(1.2)
                .foregroundStyle(Color.lazyBlack.opacity(0.65))
            ChipFlow { content() }
        }
    }

    private func modeRow(_ title: String, _ detail: String, _ binding: Binding<Bool>) -> some View {
        let on = binding.wrappedValue
        return Button {
            binding.wrappedValue.toggle()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased()).font(.lazySubhead).kerning(0.8)
                    Text(detail).font(.lazyCaption).opacity(0.75)
                }
                Spacer()
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .bold))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .lazyCard(backgroundColor: on ? .lazyRose : .white, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.lazyBlack)
    }
}

/// Casilla "+" del selector de fotos. Vista propia porque el label de
/// PhotosPicker no esta aislado al main actor.
private struct AddPhotoTile: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(Color.lazyBlack)
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .lazyCard(backgroundColor: .lazyRose, cornerRadius: 14, offset: 3)
    }
}
