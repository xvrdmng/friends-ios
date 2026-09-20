import SwiftUI

/// El mazo de swipe. El mismo componente sirve para citas, amistad, idiomas y
/// grupos: solo cambia el `context` con el que se pide el mazo al servidor.
///
/// En la pestana Friends hay un selector Amistad | Idiomas dentro de la misma
/// pantalla.
struct DeckView: View {
    let context: DeckContext
    var groupSlug: String? = nil
    var groupID: String? = nil
    var groupName: String? = nil
    /// Solo cuando se presenta como pantalla completa (mazo de un grupo).
    var onClose: (() -> Void)? = nil

    @State private var active: DeckContext
    @State private var models: [DeckContext: DeckViewModel] = [:]
    @State private var command: DeckViewModel.Decision?
    /// Una sola presentacion: apilar varios `.sheet` en la misma vista deja
    /// mudos todos menos uno.
    @State private var sheet: Sheet?
    @State private var chatMatch: Match?

    private enum Sheet: Identifiable {
        case detail(DeckCard)
        case report(ReportTarget)
        case filters, languages
        case paywall(PaywallReason)

        var id: String {
            switch self {
            case .detail(let card):    "detail:\(card.userId)"
            case .report(let target):  "report:\(target.id)"
            case .filters:             "filters"
            case .languages:           "languages"
            case .paywall(let reason): "paywall:\(reason)"
            }
        }
    }
    @State private var account = AccountStore.shared
    @State private var store = StoreService.shared
    @State private var locationService = LocationService.shared
    @Environment(\.scenePhase) private var scenePhase

    init(context: DeckContext, groupSlug: String? = nil, groupID: String? = nil, groupName: String? = nil, onClose: (() -> Void)? = nil) {
        self.context = context
        self.groupSlug = groupSlug
        self.groupID = groupID
        self.groupName = groupName
        self.onClose = onClose
        _active = State(initialValue: context)
    }

    private var model: DeckViewModel {
        if let existing = models[active] { return existing }
        let created = DeckViewModel(context: active, groupSlug: groupSlug, groupID: groupID)
        DispatchQueue.main.async { models[active] = created }
        return created
    }

    var body: some View {
        let model = model
        NavigationStack {
            VStack(spacing: 12) {
                if context == .friendship || context == .language { contextPicker }
                stack(model)
                if case .ready = model.phase { actions(model) }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(groupName ?? active.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar(model) }
            .toolbarTitleDisplayMode(.inline)
        }
        .tint(active.tint)
        .errorAlert(Binding(get: { model.error }, set: { model.error = $0 }))
        .overlay { celebration(model) }
        .task(id: active) {
            store.start()
            await account.refresh()
            await model.load()
            await LocationService.shared.syncToServer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await LocationService.shared.syncToServer() } }
        }
        .onChange(of: model.showPaywall) { _, show in
            if show { sheet = .paywall(.likeLimit); model.showPaywall = false }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .detail(let card):
                CardDetailView(
                    card: card,
                    onReport: {
                        sheet = .report(ReportTarget(kind: .user, id: card.userId,
                                                     userID: card.userId, displayName: card.displayName))
                    },
                    onBlock: {
                        sheet = nil
                        Task { if await SafetyActions.block(userID: card.userId) { model.remove(userID: card.userId) } }
                    }
                )
            case .report(let target):
                ReportSheet(target: target) { didBlock in if didBlock { model.remove(userID: target.id) } }
            case .filters:
                FiltersView { Task { await model.load(reset: true) } }
            case .languages:
                LanguagesEditorView { Task { await model.load(reset: true) } }
            case .paywall(let reason):
                PaywallView(reason: reason)
            }
        }
        .fullScreenCover(item: $chatMatch) { match in
            ChatLauncher(match: match) { _ in chatMatch = nil }
        }
    }

    // MARK: - Barra de navegacion

    @ToolbarContentBuilder
    private func toolbar(_ model: DeckViewModel) -> some ToolbarContent {
        if let onClose {
            ToolbarItem(placement: .topBarLeading) {
                Button("Volver", systemImage: "chevron.left", action: onClose)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if store.isPremium {
                Label("Premium", systemImage: "star.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Cuenta premium")
            } else if let left = model.likesLeft {
                Button { sheet = .paywall(.likeLimit) } label: {
                    Label("\(left)", systemImage: "heart")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote)
                }
                .accessibilityLabel("Te quedan \(left) likes hoy")
            }
        }

        if active != .group {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Filtros", systemImage: "line.3.horizontal.decrease") { sheet = .filters }
            }
        }
    }

    private var contextPicker: some View {
        Picker("Modo", selection: $active) {
            Text("Amistad").tag(DeckContext.friendship)
            Text("Idiomas").tag(DeckContext.language)
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    // MARK: - Pila

    @ViewBuilder
    private func stack(_ model: DeckViewModel) -> some View {
        switch model.phase {
        case .loading:
            ProgressView("Buscando gente…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            ZStack {
                ForEach(Array(model.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                    if index == 0 {
                        DraggableCard(card: card, command: $command,
                                      onDecision: { model.decide($0) },
                                      onInfo: { sheet = .detail(card) })
                            .id(card.id).transition(.identity)
                    } else {
                        ProfileCardView(card: card)
                            .scaleEffect(1 - CGFloat(index) * 0.045)
                            .offset(y: CGFloat(index) * 12)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .id(card.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            emptyState(model)

        case .failed(let message):
            ContentUnavailableView {
                Label("No pudimos cargar el mazo", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") { Task { await model.load(reset: true) } }
                    .buttonStyle(.glassProminent)
            }

        case .needs(let requirement):
            requirementState(requirement, model)
        }
    }

    private func emptyState(_ model: DeckViewModel) -> some View {
        ContentUnavailableView {
            Label("Por ahora no hay nadie más", systemImage: "person.slash")
        } description: {
            Text(active == .group
                 ? "Ya viste a todos los miembros. Vuelve cuando se sumen más."
                 : "Amplía tu distancia o tu rango de edad, o vuelve más tarde.")
        } actions: {
            Button("Actualizar") { Task { await model.load(reset: true) } }
                .buttonStyle(.glassProminent)
            if active != .group {
                Button("Ajustar filtros") { sheet = .filters }
            }
        }
    }

    @ViewBuilder
    private func requirementState(_ requirement: DeckViewModel.Requirement, _ model: DeckViewModel) -> some View {
        switch requirement {
        case .location:
            let denied = locationService.access == .denied
            ContentUnavailableView {
                Label(denied ? "Tu ubicación está desactivada" : "Activa tu ubicación",
                      systemImage: denied ? "location.slash" : "location")
            } description: {
                Text(denied
                     ? "Actívala en Ajustes para ver gente cerca. Nunca mostramos tu posición exacta a nadie."
                     : "La usamos solo para mostrarte gente cerca. Nadie ve tu posición exacta, solo la distancia aproximada.")
            } actions: {
                Button(denied ? "Abrir Ajustes" : "Activar ubicación") {
                    if denied {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } else {
                        Task {
                            if await locationService.requestAccess() {
                                await locationService.syncToServer()
                                await model.load(reset: true)
                            }
                        }
                    }
                }
                .buttonStyle(.glassProminent)
            }

        case .mode:
            ContentUnavailableView {
                Label("Activa \(active.title.lowercased()) en tu perfil", systemImage: active.symbol)
            } description: {
                Text("Ahora mismo no apareces ni ves a nadie en este modo.")
            } actions: {
                Button("Activarlo") { Task { await enableMode(model) } }
                    .buttonStyle(.glassProminent)
            }

        case .languages:
            ContentUnavailableView {
                Label("Elige tus idiomas", systemImage: "character.bubble")
            } description: {
                Text("Emparejamos a quien habla lo que tú aprendes y aprende lo que tú hablas.")
            } actions: {
                Button("Elegir idiomas") { sheet = .languages }
                    .buttonStyle(.glassProminent)
            }

        case .completeProfile:
            ContentUnavailableView {
                Label("Completa tu perfil", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text("Necesitas al menos 2 fotos, tus datos básicos y 3 intereses.")
            }
        }
    }

    private func enableMode(_ model: DeckViewModel) async {
        var payload = OnboardingPayload()
        switch active {
        case .friendship: payload.modeFriendship = true
        case .language:   payload.modeLanguage = true
        default:          payload.modeDating = true
        }
        do {
            try await APIClient.shared.send(.onboarding, body: payload)
            await model.load(reset: true)
        } catch {
            model.error = AlertMessage("No se pudo activar", message: "Revisa tu perfil e inténtalo de nuevo.")
        }
    }

    // MARK: - Acciones

    private func actions(_ model: DeckViewModel) -> some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 16) {
                actionButton("arrow.uturn.backward", tint: .yellow, size: 50,
                             label: "Deshacer", isEnabled: model.canRewind) {
                    if store.isPremium { Task { await model.rewind() } } else { sheet = .paywall(.rewind) }
                }
                actionButton("xmark", tint: .red, size: 66, label: "No me interesa") { command = .pass }
                actionButton("star.fill", tint: .cyan, size: 50, label: "Superlike") {
                    if store.isPremium { command = .superlike } else { sheet = .paywall(.superlike) }
                }
                actionButton("heart.fill", tint: .green, size: 66, label: "Me gusta") { command = .like }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func actionButton(_ symbol: String, tint: Color, size: CGFloat, label: String,
                              isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(tint)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func celebration(_ model: DeckViewModel) -> some View {
        if let match = model.newMatch {
            MatchCelebrationView(match: match, myPhoto: account.firstPhotoURL, myName: account.displayName,
                                 onMessage: { model.dismissMatch(); chatMatch = match },
                                 onKeepSwiping: { model.dismissMatch() })
                .transition(.opacity)
        }
    }
}
