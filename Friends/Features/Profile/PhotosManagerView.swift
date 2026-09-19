import PhotosUI
import SwiftUI

/// Gestor de fotos del perfil: subir, borrar y reordenar. La primera es la que
/// se ve en el mazo.
struct PhotosManagerView: View {
    var api: any APIService = APIClient.shared
    var onChanged: () -> Void = {}

    static let maxPhotos = 6
    static let minPhotos = 2

    @Environment(\.dismiss) private var dismiss
    @State private var photos: [PhotoItem] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = true
    @State private var isUploading = false
    @State private var toast: Toast?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                DoodleBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(photos.count)/\(Self.maxPhotos) FOTOS · MÍNIMO \(Self.minPhotos)")
                            .font(.lazyMono).foregroundStyle(.secondary)
                        Text("Mantén pulsada una foto para moverla. La primera es tu portada.")
                            .font(.lazyCaption).foregroundStyle(.secondary)

                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            grid
                        }
                        if photos.count < Self.minPhotos {
                            Text("Con menos de \(Self.minPhotos) fotos no apareces en el mazo.")
                                .font(.lazyCaption).foregroundStyle(Color.lazyRed)
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Tus fotos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
            .toast($toast)
        }
        .task { await load() }
        .onChange(of: pickerItems) { _, items in Task { await upload(items) } }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(photos) { photo in
                tile(photo)
                    .draggable(photo.id) {
                        RemoteImage(url: photo.thumbURL).frame(width: 90, height: 115).clipShape(.rect(cornerRadius: 12))
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let dragged = items.first else { return false }
                        move(dragged, before: photo.id)
                        return true
                    }
            }
            if photos.count < Self.maxPhotos {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: Self.maxPhotos - photos.count,
                             matching: .images) {
                    AddPhotoTile(isUploading: isUploading)
                }
                .disabled(isUploading)
            }
        }
    }

    private func tile(_ photo: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            RemoteImage(url: photo.thumbURL)
                .frame(maxWidth: .infinity).frame(height: 140).clipped()
                .lazyCard(cornerRadius: 16).stickerPadding()

            Button { Task { await remove(photo) } } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 28, height: 28)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 2))
            }
            .padding(10)
            .accessibilityLabel("Borrar foto")

            if !photo.isApproved {
                Text("EN REVISIÓN").font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.lazyBlack)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.lazyNotice, in: Capsule())
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    // MARK: - Datos

    private func load() async {
        defer { isLoading = false }
        if let response: PhotosResponse = try? await api.send(.photos) { photos = response.photos }
    }

    private func upload(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        pickerItems = []
        isUploading = true
        defer { isUploading = false }

        for item in items where photos.count < Self.maxPhotos {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = Self.jpeg(from: data) else { continue }
            do {
                let response: PhotoResponse = try await api.upload(
                    .photos, field: "image", data: jpeg, filename: "photo.jpg", mimeType: "image/jpeg", fields: [:]
                )
                photos.append(response.photo)
            } catch {
                toast = Toast(text: "No se pudo subir una foto", isError: true)
            }
        }
        onChanged()
    }

    private func remove(_ photo: PhotoItem) async {
        do {
            try await api.send(.photo(id: photo.id))
            photos.removeAll { $0.id == photo.id }
            onChanged()
        } catch {
            toast = Toast(text: "No se pudo borrar la foto", isError: true)
        }
    }

    private func move(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID,
              let from = photos.firstIndex(where: { $0.id == draggedID }),
              let to = photos.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.snappy) {
            let photo = photos.remove(at: from)
            photos.insert(photo, at: to)
        }
        Task { await persistOrder() }
    }

    private func persistOrder() async {
        do {
            try await api.send(.orderPhotos, body: OrderRequest(ids: photos.map(\.id)))
            onChanged()
        } catch {
            toast = Toast(text: "No se pudo guardar el orden", isError: true)
            await load()
        }
    }

    /// Vista aparte porque la etiqueta de `PhotosPicker` no esta aislada al main actor.
    private struct AddPhotoTile: View {
        let isUploading: Bool

        var body: some View {
            VStack(spacing: 8) {
                if isUploading { ProgressView() }
                else { Image(systemName: "plus").font(.system(size: 26, weight: .black)) }
                Text(isUploading ? "Subiendo…" : "Añadir").font(.lazyCaption)
            }
            .foregroundStyle(Color.lazyBlack)
            .frame(maxWidth: .infinity).frame(height: 140)
            .lazyCard(backgroundColor: .lazyRose, cornerRadius: 16).stickerPadding()
        }
    }

    /// Una foto de camara pesa varios MB: se reduce antes de subirla.
    private static func jpeg(from data: Data, maxSide: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image.jpegData(compressionQuality: 0.85) }

        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
