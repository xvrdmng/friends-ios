import SwiftUI

/// Perfil propio: fotos, datos, ajustes, privacidad y cuenta.
struct ProfileView: View {
    let session: SessionViewModel

    @State private var account = AccountStore.shared
    @State private var store = StoreService.shared
    @State private var push = PushService.shared
    @State private var likesReceived: ReceivedLikesResponse?
    @State private var isDeleting = false
    @State private var languageNames: [String: String] = [:]
    @State private var error: AlertMessage?

    /// Una sola presentacion, no una por pantalla: SwiftUI solo respeta UN
    /// `.sheet` por vista, y apilar ocho dejaba mudos casi todos los botones.
    @State private var sheet: Sheet?
    @State private var confirm: AccountAction?

    private enum Sheet: Identifiable {
        case edit, photos, filters, languages, preview, blocked
        case export(URL)
        case paywall(PaywallReason)

        var id: String {
            switch self {
            case .edit: "edit"
            case .photos: "photos"
            case .filters: "filters"
            case .languages: "languages"
            case .preview: "preview"
            case .blocked: "blocked"
            case .export(let url): "export:\(url.absoluteString)"
            case .paywall(let reason): "paywall:\(reason)"
            }
        }
    }

    private enum AccountAction: Identifiable {
        case signOut, delete
        var id: Self { self }

        var title: String {
            switch self {
            case .signOut: "¿Cerrar sesión?"
            case .delete:  "¿Borrar tu cuenta?"
            }
        }

        var message: String {
            switch self {
            case .signOut: "Tu cuenta y tus datos se quedan guardados. Volverás a entrar con tu passkey."
            case .delete:  "Desapareces al instante de la app. Tus datos se borran del todo a los 30 días."
            }
        }

        var button: String {
            switch self {
            case .signOut: "Cerrar sesión"
            case .delete:  "Borrar mi cuenta"
            }
        }
    }

    private var profile: MeResponse.Profile? { account.me?.profile ?? session.me?.profile }
    private var photos: [PhotoItem] { account.me?.photos ?? [] }

    var body: some View {
        NavigationStack {
            List {
                Section { header }
                Section("Fotos") { photoStrip }
                premiumSection
                likesSection
                aboutSection
                datingSection
                friendshipSection
                languagesSection
                settingsSection
                accountSection
                legalSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Perfil")
            .refreshable { await reload() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar") { sheet = .edit }
                }
            }
        }
        .errorAlert($error)
        .task { await reload() }
        .sheet(item: $sheet) { which in
            switch which {
            case .edit:      EditProfileView { Task { await reload() } }
            case .photos:    PhotosManagerView { Task { await reload() } }
            case .filters:   FiltersView()
            case .languages: LanguagesEditorView { Task { await reload() } }
            case .preview:   ProfilePreviewView(me: account.me)
            case .blocked:   NavigationStack { BlockedUsersView() }
            case .export(let url):     ShareSheet(url: url)
            case .paywall(let reason): PaywallView(reason: reason)
            }
        }
        .confirmationDialog(confirm?.title ?? "",
                            isPresented: Binding(get: { confirm != nil },
                                                 set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible,
                            presenting: confirm) { action in
            Button(action.button, role: .destructive) {
                switch action {
                case .signOut: Task { await session.signOut() }
                case .delete:  Task { await deleteAccount() }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: 14) {
            AvatarView(url: account.firstPhotoURL, name: account.displayName, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName ?? account.displayName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let age = profile?.age { Tag(text: "\(age) años") }
                    if let city = profile?.city, !city.isEmpty { Tag(text: city) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var photoStrip: some View {
        Button { sheet = .photos } label: {
            HStack(spacing: 10) {
                ForEach(photos.prefix(4)) { photo in
                    RemoteImage(url: photo.thumbURL)
                        .frame(width: 60, height: 76)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                        .opacity(photo.isApproved ? 1 : 0.5)
                }
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.plus").font(.title3)
                    Text("\(photos.count)/6").font(.caption)
                }
                .foregroundStyle(Color.accentColor)
                .frame(width: 60, height: 76)
                .background(Color(.secondarySystemFill), in: .rect(cornerRadius: 10, style: .continuous))
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gestionar fotos, \(photos.count) de 6")
    }

    // MARK: - Secciones

    @ViewBuilder
    private var premiumSection: some View {
        Section {
            if store.isPremium {
                LabeledContent {
                    if let until = store.premiumUntil {
                        Text(until.formatted(.dateTime.day().month().year()))
                    }
                } label: {
                    Label("Friends Premium", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
            } else {
                Button { sheet = .paywall(.generic) } label: {
                    LabeledContent {
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hazte premium")
                                Text("Likes sin límite, ver quién te quiere y más.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var likesSection: some View {
        if let likes = likesReceived, likes.count > 0 {
            Section {
                Button {
                    if !likes.premium { sheet = .paywall(.likesReceived) }
                } label: {
                    LabeledContent {
                        if !likes.premium {
                            Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.tertiary)
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(likes.count) \(likes.count == 1 ? "persona" : "personas") te dieron like")
                                if !likes.premium {
                                    Text("Con premium ves quiénes son.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(likes.premium)

                if likes.premium, let people = likes.people, !people.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(people) { person in
                                VStack(spacing: 6) {
                                    AvatarView(url: person.thumbUrl, name: person.displayName, size: 60)
                                    Text(person.displayName).font(.caption).lineLimit(1)
                                }
                                .frame(width: 72)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("Sobre ti") {
            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
            } else {
                Text("Todavía no has escrito nada sobre ti.")
                    .foregroundStyle(.secondary)
            }
            if !traits.isEmpty {
                ChipFlow {
                    ForEach(traits, id: \.self) { Tag(text: $0) }
                }
            }
        }
    }

    private enum Mode { case dating, friendship, language }

    /// Citas y Amistad: un interruptor para aparecer y ver gente en ese modo, y
    /// a quien se le ensena. Cada modo guarda su propia preferencia.
    private var datingSection: some View { modeSection(.dating) }
    private var friendshipSection: some View { modeSection(.friendship) }

    private func modeSection(_ mode: Mode) -> some View {
        let isDating = mode == .dating
        let enabled = (isDating ? profile?.modeDating : profile?.modeFriendship) ?? isDating
        let preference = (isDating ? profile?.datingPreference : profile?.friendshipPreference) ?? "everyone"
        return Section {
            Toggle(isDating ? "Mostrarme en Citas" : "Mostrarme en Amistad", isOn: Binding(
                get: { enabled },
                set: { on in Task { await saveMode(mode, enabled: on) } }
            ))
            if enabled {
                Text(isDating ? "Quiero conocer a" : "Quiero hacer amistad con")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ChipFlow {
                    ForEach([("Mujeres", "women"), ("Hombres", "men"), ("Todos", "everyone")], id: \.1) { label, value in
                        ChoiceChip(label: label, isSelected: preference == value) {
                            Task { await savePreference(mode, value) }
                        }
                    }
                }
            }
        } header: {
            Text(isDating ? "Citas" : "Amistad")
        }
    }

    /// Toda la tarjeta abre el editor: igual que "Sobre ti", sin botones extra.
    private var languagesSection: some View {
        let entries = account.me?.languages ?? []
        let native = entries.filter { $0.kind == "native" }
        let learning = entries.filter { $0.kind == "learning" }
        return Section("Idiomas") {
            Toggle("Mostrarme en Idiomas", isOn: Binding(
                get: { profile?.modeLanguage ?? false },
                set: { on in Task { await saveMode(.language, enabled: on) } }
            ))
            Button { sheet = .languages } label: {
                VStack(alignment: .leading, spacing: 14) {
                    languageRow("Idiomas nativos", native.map { languageNames[$0.languageId] ?? "…" })
                    languageRow("Quiero aprender", learning.map { languageNames[$0.languageId] ?? "…" })
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Toca para editar tus idiomas")
        }
    }

    private func languageRow(_ title: String, _ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if names.isEmpty {
                Text("Ninguno todavía").foregroundStyle(.tertiary)
            } else {
                ChipFlow { ForEach(names, id: \.self) { Tag(text: $0, large: true) } }
            }
        }
    }

    private func saveMode(_ mode: Mode, enabled: Bool) async {
        var payload = OnboardingPayload()
        switch mode {
        case .dating:     payload.modeDating = enabled
        case .friendship: payload.modeFriendship = enabled
        case .language:   payload.modeLanguage = enabled
        }
        await save(payload)
    }

    private func savePreference(_ mode: Mode, _ value: String) async {
        var payload = OnboardingPayload()
        if mode == .dating { payload.datingPreference = value } else { payload.friendshipPreference = value }
        await save(payload)
    }

    private func save(_ payload: OnboardingPayload) async {
        do {
            try await APIClient.shared.send(.onboarding, body: payload)
            await account.refresh()
        } catch {
            self.error = AlertMessage("No se pudo guardar", message: "Inténtalo de nuevo.")
        }
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

    private var settingsSection: some View {
        Section("Ajustes") {
            notificationsRow
            Button("Ver cómo te ven", systemImage: "eye") { sheet = .preview }
            Button("Filtros de búsqueda", systemImage: "line.3.horizontal.decrease") { sheet = .filters }
            Button("Cuentas bloqueadas", systemImage: "hand.raised") { sheet = .blocked }
        }
    }

    /// Quien dijo que no en el primer match no tiene otra forma de volver
    /// atras: el sistema ya no vuelve a preguntar.
    @ViewBuilder
    private var notificationsRow: some View {
        switch push.access {
        case .granted:
            LabeledContent {
                Text("Activadas").foregroundStyle(.secondary)
            } label: {
                Label("Avisos", systemImage: "bell.badge")
            }
        case .notDetermined:
            Button("Avisarme de matches y mensajes", systemImage: "bell") {
                Task { await push.requestAccess() }
            }
        case .denied:
            Button("Activar avisos en Ajustes", systemImage: "bell.slash") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        }
    }

    private var accountSection: some View {
        Section("Cuenta") {
            Button("Descargar mis datos", systemImage: "square.and.arrow.down") { Task { await export() } }
            Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") { confirm = .signOut }
            Button("Borrar mi cuenta", systemImage: "trash", role: .destructive) { confirm = .delete }
                .disabled(isDeleting)
        }
    }

    /// Apple pide que las dos paginas esten a la vista dentro de la app, no
    /// solo en la ficha de la App Store ni solo detras del paywall.
    private var legalSection: some View {
        Section {
            Link(destination: LegalLinks.terms) {
                Label("Términos de uso", systemImage: "doc.text")
            }
            Link(destination: LegalLinks.privacy) {
                Label("Privacidad", systemImage: "hand.raised.square")
            }
        } footer: {
            Text("Friends \(Bundle.appVersion)")
        }
    }

    // MARK: - Datos

    private func reload() async {
        await push.refreshAccess()
        await account.refresh()
        likesReceived = try? await APIClient.shared.send(.likesReceived(context: nil))
        if languageNames.isEmpty, let response: LanguagesResponse = try? await APIClient.shared.send(.languages) {
            languageNames = Dictionary(uniqueKeysWithValues: response.languages.map { ($0.id, $0.name) })
        }
    }

    /// El JSON del servidor se guarda en un fichero temporal para poder compartirlo.
    private func export() async {
        do {
            let data: Data = try await APIClient.shared.sendRaw(.exportMe)
            let url = URL.temporaryDirectory.appending(path: "friends-datos.json")
            try data.write(to: url, options: .atomic)
            sheet = .export(url)
        } catch {
            self.error = AlertMessage("No se pudieron descargar tus datos")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await APIClient.shared.send(.deleteMe)
            await session.signOut()
        } catch {
            self.error = AlertMessage("No se pudo borrar la cuenta")
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

extension Bundle {
    /// "1.0 (12)": la version de marketing y el build, que es lo que hay que
    /// pedirle a alguien que reporta un fallo.
    static var appVersion: String {
        let short = main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
