import PhotosUI
import SwiftUI

/// Crear un grupo: nombre, categoria, intereses y si es publico o privado.
struct CreateGroupView: View {
    var api: any APIService = APIClient.shared
    var onCreated: (FriendGroup) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var category = "sports"
    @State private var isPrivate = false
    @State private var useMyLocation = true
    @State private var selectedInterests: Set<String> = []
    @State private var interests: [InterestItem] = []
    @State private var coverItem: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var isSaving = false
    @State private var error: AlertMessage?

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !isSaving
    }

    /// Solo se ofrecen los intereses de la categoria elegida.
    private var categoryInterests: [InterestItem] {
        interests.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { coverPicker }
                    .listRowInsets(.init())

                Section {
                    TextField("Nombre", text: $name)
                        .textInputAutocapitalization(.sentences)
                    TextField("¿De qué va el grupo?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Sobre el grupo")
                } footer: {
                    Text("El nombre necesita al menos 3 caracteres.")
                }

                Section("Categoría") { categoryChips }

                if !categoryInterests.isEmpty {
                    Section("Intereses del grupo") { interestChips }
                }

                Section {
                    Toggle("Grupo privado", isOn: $isPrivate)
                    Toggle("Usar mi ubicación", isOn: $useMyLocation)
                } footer: {
                    Text(isPrivate
                         ? "Solo se entra con código de invitación."
                         : "Cualquiera puede encontrarlo y unirse.")
                }
            }
            .navigationTitle("Nuevo grupo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { Task { await create() } }.disabled(!canSave)
                }
            }
            .errorAlert($error)
            .disabled(isSaving)
        }
        .task { await loadInterests() }
        .onChange(of: coverItem) { _, item in Task { await loadCover(item) } }
    }

    // MARK: - Campos

    private var coverPicker: some View {
        // La etiqueta del picker es un closure Sendable: el estado se lee aqui
        // fuera, no dentro, o no compila con concurrencia estricta.
        let data = coverData
        return PhotosPicker(selection: $coverItem, matching: .images) {
            CoverTile(data: data)
        }
        .accessibilityLabel("Elegir portada")
    }

    private var categoryChips: some View {
        ChipFlow {
            ForEach(Array(Labels.categories.keys).sorted(), id: \.self) { key in
                let item = Labels.categories[key]!
                ChoiceChip(label: item.name, emoji: item.emoji, isSelected: category == key) {
                    category = key
                    selectedInterests = []
                }
            }
        }
    }

    private var interestChips: some View {
        ChipFlow {
            ForEach(categoryInterests) { interest in
                ChoiceChip(label: interest.name, emoji: interest.emoji,
                           isSelected: selectedInterests.contains(interest.id)) {
                    if selectedInterests.contains(interest.id) { selectedInterests.remove(interest.id) }
                    else { selectedInterests.insert(interest.id) }
                }
            }
        }
    }

    // MARK: - Datos

    private func loadInterests() async {
        if let response: InterestsResponse = try? await api.send(.interests) { interests = response.interests }
    }

    /// La portada de camara pesa varios MB: se reduce antes de subirla.
    private static func jpeg(from data: Data, maxSide: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image.jpegData(compressionQuality: 0.85) }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.85)
    }

    private func loadCover(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        coverData = data
    }

    private func create() async {
        isSaving = true
        defer { isSaving = false }

        let body = CreateGroupRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            // El enum de Rails usa estos valores, no "public"/"private".
            visibility: isPrivate ? "private_group" : "public_group",
            interestIds: Array(selectedInterests),
            useMyLocation: useMyLocation
        )

        do {
            let created: GroupResponse = try await api.send(.createGroup, body: body)
            var group = created.group

            // La portada va en una segunda peticion, multipart. Si falla, el
            // grupo ya existe: no se pierde lo escrito, solo se queda sin foto.
            if let coverData, let jpeg = Self.jpeg(from: coverData) {
                if let withCover: GroupResponse = try? await api.upload(
                    .groupCover(slug: group.slug), field: "cover", data: jpeg,
                    filename: "portada.jpg", mimeType: "image/jpeg", fields: [:]
                ) {
                    group = withCover.group
                }
            }

            onCreated(group)
            dismiss()
        } catch APIError.server(_, let message) {
            error = AlertMessage("No se pudo crear el grupo", message: message)
        } catch {
            self.error = AlertMessage("No se pudo crear el grupo")
        }
    }
}

/// La etiqueta de `PhotosPicker` no esta aislada al main actor, asi que va en
/// su propia vista: con concurrencia estricta, meter aqui un modificador
/// aislado no compila.
private struct CoverTile: View {
    let data: Data?

    var body: some View {
        ZStack {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus").font(.title)
                    Text("Portada (opcional)").font(.subheadline)
                }
                .foregroundStyle(Color.accentColor)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemFill))
        .clipped()
    }
}
