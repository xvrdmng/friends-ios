import SwiftUI

/// Perfil propio: fotos, datos, ajustes, privacidad y cuenta.
struct ProfileView: View {
    let session: SessionViewModel

    @State private var account = AccountStore.shared
    @State private var store = StoreService.shared
    @State private var likesReceived: ReceivedLikesResponse?
    @State private var showEdit = false
    @State private var showPhotos = false
    @State private var showFilters = false
    @State private var showLanguages = false
    @State private var showBlocked = false
    @State private var showPreview = false
    @State private var paywallReason: PaywallReason?
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var exportURL: URL?
    @State private var toast: Toast?

    private var profile: MeResponse.Profile? { account.me?.profile ?? session.me?.profile }
    private var photos: [PhotoItem] { account.me?.photos ?? [] }

    var body: some View {
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    photoStrip
                    premiumCard
                    likesCard
                    aboutCard
                    settingsSection
                    accountSection
                }
                .padding(.horizontal, 22).padding(.trailing, 4).padding(.bottom, 110)
            }
            .drivesTabBar()
            .refreshable { await reload() }
        }
        .toast($toast)
        .task { await reload() }
        .sheet(isPresented: $showEdit) { EditProfileView { Task { await reload() } } }
        .sheet(isPresented: $showPhotos) { PhotosManagerView { Task { await reload() } } }
        .sheet(isPresented: $showFilters) { FiltersView() }
        .sheet(isPresented: $showLanguages) { LanguagesEditorView() }
        .sheet(isPresented: $showPreview) { ProfilePreviewView(me: account.me) }
        .sheet(isPresented: $showBlocked) { NavigationStack { BlockedUsersView() } }
        .sheet(item: $exportURL) { url in ShareSheet(url: url) }
        .sheet(isPresented: Binding(get: { paywallReason != nil }, set: { if !$0 { paywallReason = nil } })) {
            PaywallView(reason: paywallReason ?? .generic)
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { Task { await session.signOut() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Tu cuenta y tus datos se quedan guardados. Volverás a entrar con tu passkey.")
        }
        .confirmationDialog("¿Borrar tu cuenta?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar mi cuenta", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Desapareces al instante de la app. Tus datos se borran del todo a los 30 días.")
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: 14) {
            Button { showPhotos = true } label: {
                AvatarView(url: account.firstPhotoURL, name: account.displayName, size: 82)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cambiar fotos")

            VStack(alignment: .leading, spacing: 6) {
                Text(profile?.displayName ?? account.displayName)
                    .font(.lazyHeading).lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    if let age = profile?.age { Tag(text: "\(age)") }
                    if let city = profile?.city, !city.isEmpty { Tag(text: city, color: .lazyMint) }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(.top, 8)
    }

    private var photoStrip: some View {
        Button { showPhotos = true } label: {
            HStack(spacing: 10) {
                ForEach(photos.prefix(4)) { photo in
                    RemoteImage(url: photo.thumbURL)
                        .frame(width: 64, height: 80).clipped()
                        .lazyCard(cornerRadius: 12, offset: 2).padding(.trailing, 2).padding(.bottom, 2)
                        .opacity(photo.isApproved ? 1 : 0.5)
                }
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 18, weight: .bold))
                    Text("\(photos.count)/6").font(.lazyMono)
                }
                .foregroundStyle(Color.lazyBlack)
                .frame(width: 64, height: 80)
                .lazyCard(backgroundColor: .lazyRose, cornerRadius: 12, offset: 2)
                .padding(.trailing, 2).padding(.bottom, 2)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gestionar fotos")
    }

    // MARK: - Tarjetas

    @ViewBuilder
    private var premiumCard: some View {
        if store.isPremium {
            HStack(spacing: 12) {
                Text("★").font(.lazyHeading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friends Premium").font(.lazySubhead)
                    if let until = store.premiumUntil {
                        Text("Hasta el \(until.formatted(.dateTime.day().month().year()))")
                            .font(.lazyCaption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .foregroundStyle(Color.lazyBlack)
            .padding(16).lazyCard(backgroundColor: .lazyYellow).stickerPadding()
        } else {
            Button { paywallReason = .generic } label: {
                HStack(spacing: 12) {
                    Text("★").font(.lazyHeading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hazte premium").font(.lazySubhead)
                        Text("Likes sin límite, ver quién te quiere y más.")
                            .font(.lazyCaption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .black))
                }
                .foregroundStyle(Color.lazyBlack)
                .padding(16).lazyCard(backgroundColor: .lazyYellow).stickerPadding()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var likesCard: some View {
        if let likes = likesReceived, likes.count > 0 {
            Button {
                if !likes.premium { paywallReason = .likesReceived }
            } label: {
                HStack(spacing: 12) {
                    Text("💘").font(.lazyHeading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(likes.count) \(likes.count == 1 ? "persona" : "personas") te dieron like")
                            .font(.lazySubhead).multilineTextAlignment(.leading)
                        if !likes.premium {
                            Text("Con premium ves quiénes son.").font(.lazyCaption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    if !likes.premium { Image(systemName: "lock.fill").font(.system(size: 15, weight: .black)) }
                }
                .foregroundStyle(Color.lazyBlack)
                .padding(16).lazyCard(backgroundColor: .lazyRose).stickerPadding()
            }
            .buttonStyle(.plain)
            .disabled(likes.premium)

            if likes.premium, let people = likes.people, !people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(people) { person in
                            VStack(spacing: 6) {
                                AvatarView(url: person.thumbUrl, name: person.displayName, size: 64)
                                Text(person.displayName).font(.lazyCaption).lineLimit(1)
                            }
                            .frame(width: 76).foregroundStyle(Color.lazyBlack)
                        }
                    }
                    .padding(.vertical, 4).padding(.trailing, 6)
                }
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SOBRE TI").font(.lazyMono).foregroundStyle(.secondary)
                Spacer()
                Button("Editar") { showEdit = true }
                    .font(.lazyMono).foregroundStyle(Color.lazyBlack)
            }
            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio).font(.lazyBody).foregroundStyle(Color.lazyBlack)
            } else {
                Text("Todavía no has escrito nada sobre ti.")
                    .font(.lazyCaption).foregroundStyle(.secondary)
            }
            ChipFlow(spacing: 8) {
                ForEach(traits, id: \.self) { trait in
                    Text(trait).font(.lazyCaption).foregroundStyle(Color.lazyBlack)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .lazyCard(cornerRadius: 14, offset: 2).padding(.trailing, 2).padding(.bottom, 2)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .lazyCard().stickerPadding()
    }

    private var traits: [String] {
        guard let profile else { return [] }
        return [
            profile.occupation,
            profile.heightCm.map { "\($0) cm" },
            profile.education.flatMap { Labels.education[$0] },
            profile.relationshipGoal.flatMap { Labels.goal[$0] },
            profile.kids.flatMap { Labels.kids[$0] },
            profile.smoking.flatMap { Labels.smoking[$0] },
            profile.drinking.flatMap { Labels.drinking[$0] }
        ].compactMap { $0 }.filter { !$0.isEmpty }
    }

    // MARK: - Ajustes y cuenta

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AJUSTES").font(.lazyMono).foregroundStyle(.secondary)
            row("Ver cómo te ven", "eye") { showPreview = true }
            row("Filtros de búsqueda", "slider.horizontal.3") { showFilters = true }
            row("Tus idiomas", "globe") { showLanguages = true }
            row("Cuentas bloqueadas", "hand.raised") { showBlocked = true }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CUENTA").font(.lazyMono).foregroundStyle(.secondary)
            row("Descargar mis datos", "square.and.arrow.down") { Task { await export() } }
            row("Cerrar sesión", "rectangle.portrait.and.arrow.right") { confirmSignOut = true }
            row("Borrar mi cuenta", "trash", tint: .lazyRed) { confirmDelete = true }
                .disabled(isDeleting)
        }
    }

    private func row(_ title: String, _ icon: String, tint: Color = .lazyBlack,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold)).frame(width: 26)
                Text(title).font(.lazySubhead)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(.secondary)
            }
            .foregroundStyle(tint)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .lazyCard().stickerPadding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Datos

    private func reload() async {
        await account.refresh()
        likesReceived = try? await APIClient.shared.send(.likesReceived)
    }

    /// El JSON del servidor se guarda en un fichero temporal para poder compartirlo.
    private func export() async {
        do {
            let data: Data = try await APIClient.shared.sendRaw(.exportMe)
            let url = URL.temporaryDirectory.appending(path: "friends-datos.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            toast = Toast(text: "No se pudieron descargar tus datos", isError: true)
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await APIClient.shared.send(.deleteMe)
            await session.signOut()
        } catch {
            toast = Toast(text: "No se pudo borrar la cuenta", isError: true)
        }
    }
}

/// Hoja nativa para compartir o guardar el fichero de datos.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
