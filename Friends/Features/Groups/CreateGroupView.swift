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
    @State private var toast: Toast?

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !isSaving
    }

    /// Solo se ofrecen los intereses de la categoria elegida.
    private var categoryInterests: [InterestItem] {
        interests.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DoodleBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        coverPicker
                        field("Nombre") {
                            TextField("Fútbol los domingos", text: $name)
                                .font(.lazyBody).textInputAutocapitalization(.sentences)
                        }
                        field("Descripción") {
                            TextField("¿De qué va el grupo?", text: $description, axis: .vertical)
                                .font(.lazyBody).lineLimit(3...6)
                        }
                        categorySection
                        if !categoryInterests.isEmpty { interestsSection }
                        options
                    }
                    .padding(22).padding(.bottom, 20)
                }
            }
            .navigationTitle("Nuevo grupo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creando…" : "Crear") { Task { await create() } }.disabled(!canSave)
                }
            }
            .toast($toast)
        }
        .task { await loadInterests() }
        .onChange(of: coverItem) { _, item in Task { await loadCover(item) } }
    }

    // MARK: - Campos

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.lazyMono).foregroundStyle(.secondary)
            content()
                .foregroundStyle(Color.lazyBlack)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .lazyCard().stickerPadding()
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $coverItem, matching: .images) {
            CoverTile(data: coverData)
        }
        .accessibilityLabel("Elegir portada")
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CATEGORÍA").font(.lazyMono).foregroundStyle(.secondary)
            ChipFlow(spacing: 8) {
                ForEach(Array(Labels.categories.keys).sorted(), id: \.self) { key in
                    let item = Labels.categories[key]!
                    ChoiceChip(label: item.name, emoji: item.emoji, selectedColor: .lazyMint,
                               isSelected: category == key) {
                        category = key
                        selectedInterests = []
                    }
                }
            }
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INTERESES DEL GRUPO").font(.lazyMono).foregroundStyle(.secondary)
            ChipFlow(spacing: 8) {
                ForEach(categoryInterests) { interest in
                    ChoiceChip(label: interest.name, emoji: interest.emoji,
                               isSelected: selectedInterests.contains(interest.id)) {
                        if selectedInterests.contains(interest.id) { selectedInterests.remove(interest.id) }
                        else { selectedInterests.insert(interest.id) }
                    }
                }
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $isPrivate) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grupo privado").font(.lazySubhead)
                    Text("Solo se entra con código de invitación.").font(.lazyCaption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $useMyLocation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Usar mi ubicación").font(.lazySubhead)
                    Text("Para que lo encuentre quien esté cerca.").font(.lazyCaption).foregroundStyle(.secondary)
                }
            }
        }
        .tint(Color.lazyRose)
        .foregroundStyle(Color.lazyBlack)
        .padding(16).lazyCard().stickerPadding()
    }

    /// Vista aparte porque la etiqueta de `PhotosPicker` no esta aislada al main actor.
    private struct CoverTile: View {
        let data: Data?

        var body: some View {
            ZStack {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 28, weight: .bold))
                        Text("Portada (opcional)").font(.lazyCaption)
                    }
                    .foregroundStyle(Color.lazyBlack)
                }
            }
            .frame(height: 150).frame(maxWidth: .infinity)
            .background(Color.lazyGray).clipped()
            .lazyCard(cornerRadius: 20).stickerPadding()
        }
    }

    // MARK: - Datos

    private func loadInterests() async {
        if let response: InterestsResponse = try? await api.send(.interests) { interests = response.interests }
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
            visibility: isPrivate ? "private_group" : "public_group",
            interestIds: Array(selectedInterests),
            useMyLocation: useMyLocation
        )

        do {
            let response: GroupResponse = try await api.send(.createGroup, body: body)
            onCreated(response.group)
            dismiss()
        } catch APIError.server(_, let message) {
            toast = Toast(text: message, isError: true)
        } catch {
            toast = Toast(text: "No se pudo crear el grupo", isError: true)
        }
    }
}
