import SwiftUI

/// El mazo de swipe. El mismo componente sirve para citas, amistad, idiomas y
/// grupos: solo cambia el `context` con el que se pide el mazo al servidor.
///
/// En la pestana Friends hay un selector Amistad | Idiomas dentro de la misma pantalla.
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
    @State private var detail: DeckCard?
    @State private var report: ReportTarget?
    @State private var paywallReason: PaywallReason?
    @State private var showFilters = false
    @State private var showLanguages = false
    @State private var chatMatch: Match?
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
        ZStack {
            DoodleBackground()
            VStack(spacing: 14) {
                header(model)
                if context == .friendship || context == .language { contextPicker }
                stack(model)
                if case .ready = model.phase { actions(model) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, onClose == nil ? 100 : 16)   // deja sitio a la barra flotante
        }
        .toast(Binding(get: { model.toast }, set: { model.toast = $0 }))
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
        .onChange(of: model.showPaywall) { _, show in if show { paywallReason = .likeLimit; model.showPaywall = false } }
        .sheet(item: $detail) { card in
            CardDetailView(card: card,
                           onReport: { detail = nil; report = ReportTarget(kind: .user, id: card.userId, userID: card.userId, displayName: card.displayName) },
                           onBlock: { detail = nil; Task { if await SafetyActions.block(userID: card.userId) { model.remove(userID: card.userId) } } })
        }
        .sheet(item: $report) { target in
            ReportSheet(target: target) { didBlock in if didBlock { model.remove(userID: target.id) } }
        }
        .sheet(isPresented: $showFilters) { FiltersView { Task { await model.load(reset: true) } } }
        .sheet(isPresented: $showLanguages) { LanguagesEditorView { Task { await model.load(reset: true) } } }
        .sheet(isPresented: Binding(get: { paywallReason != nil }, set: { if !$0 { paywallReason = nil } })) {
            PaywallView(reason: paywallReason ?? .generic)
        }
        .fullScreenCover(item: $chatMatch) { match in
            if let myID = account.userID {
                ChatView(match: match, myID: myID) { _ in chatMatch = nil }
            }
        }
    }

    // MARK: - Cabecera

    private func header(_ model: DeckViewModel) -> some View {
        HStack(spacing: 10) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.lazyBlack).frame(width: 44, height: 44).glassEffect(.regular, in: .circle)
                }
                .accessibilityLabel("Volver")
            }
            Text((groupName ?? title(for: active)).uppercased())
                .font(.lazyHeading).foregroundStyle(Color.lazyBlack).lineLimit(1).minimumScaleFactor(0.6)
            Spacer()
            if store.isPremium { Tag(text: "★ Premium", color: .lazyYellow) }
            else if let left = model.likesLeft {
                Button { paywallReason = .likeLimit } label: { Tag(text: "♥ \(left)", color: left == 0 ? .lazyNotice : .white) }
                    .buttonStyle(.plain).accessibilityLabel("\(left) likes restantes hoy")
            }
            if active != .group {
                Button { showFilters = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.lazyBlack).frame(width: 44, height: 44).glassEffect(.regular, in: .circle)
                }
                .accessibilityLabel("Filtros")
            }
        }
    }

    private var contextPicker: some View {
        HStack(spacing: 10) {
            ForEach([DeckContext.friendship, .language], id: \.self) { item in
                ChoiceChip(label: item == .friendship ? "Amistad" : "Idiomas", emoji: item == .friendship ? "🤝" : "🗣️",
                           selectedColor: .lazyMint, isSelected: active == item) { withAnimation(.snappy) { active = item } }
            }
            Spacer()
        }
    }

    private func title(for context: DeckContext) -> String {
        switch context {
        case .dating: "Citas"
        case .friendship: "Amistad"
        case .language: "Idiomas"
        case .group: "Grupo"
        }
    }

    // MARK: - Pila

    @ViewBuilder
    private func stack(_ model: DeckViewModel) -> some View {
        switch model.phase {
        case .loading:
            VStack { Spacer(); ProgressView().controlSize(.large); Text("Buscando gente…").font(.lazyMono).foregroundStyle(.secondary); Spacer() }
                .frame(maxWidth: .infinity)
        case .ready:
            ZStack {
                ForEach(Array(model.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                    if index == 0 {
                        DraggableCard(card: card, command: $command, onDecision: { model.decide($0) }, onInfo: { detail = card })
                            .id(card.id).transition(.identity)
                    } else {
                        ProfileCardView(card: card)
                            .scaleEffect(1 - CGFloat(index) * 0.045).offset(y: CGFloat(index) * 12)
                            .allowsHitTesting(false).id(card.id)
                    }
                }
            }
            .padding(.trailing, 5).padding(.bottom, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            emptyState(model)
        case .failed(let message):
            centered { StateCard(emoji: "📡", title: "No pudimos cargar el mazo", message: message,
                                 actionTitle: "Reintentar") { Task { await model.load(reset: true) } } }
        case .needs(let requirement):
            centered { requirementCard(requirement, model) }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { Spacer(); content(); Spacer() }
    }

    private func emptyState(_ model: DeckViewModel) -> some View {
        centered {
            VStack(spacing: 14) {
                StateCard(emoji: "🫥", title: "Por ahora no hay nadie más",
                          message: active == .group ? "Ya viste a todos los miembros. Vuelve cuando se sumen más."
                                                    : "Amplía tu distancia o tu rango de edad, o vuelve más tarde.",
                          actionTitle: "Actualizar") { Task { await model.load(reset: true) } }
                if active != .group {
                    Button("Ajustar filtros") { showFilters = true }
                        .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack, fillsWidth: true))
                        .padding(.trailing, 5)
                }
            }
        }
    }

    @ViewBuilder
    private func requirementCard(_ requirement: DeckViewModel.Requirement, _ model: DeckViewModel) -> some View {
        switch requirement {
        case .location:
            let denied = locationService.access == .denied
            StateCard(emoji: "📍", title: denied ? "Tu ubicación está desactivada" : "Activa tu ubicación",
                      message: denied ? "Actívala en Ajustes para ver gente cerca. Nunca mostramos tu posición exacta a nadie."
                                      : "La usamos solo para mostrarte gente cerca. Nadie ve tu posición exacta, solo la distancia aproximada.",
                      color: .lazyMint, actionTitle: denied ? "Abrir Ajustes" : "Activar ubicación") {
                if denied { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                else { Task { if await locationService.requestAccess() { await locationService.syncToServer(); await model.load(reset: true) } } }
            }
        case .mode:
            StateCard(emoji: active == .dating ? "💘" : "🤝", title: "Activa \(title(for: active).lowercased()) en tu perfil",
                      message: "Ahora mismo no apareces ni ves a nadie en este modo.",
                      color: .lazyMint, actionTitle: "Activarlo") { Task { await enableMode(model) } }
        case .languages:
            StateCard(emoji: "🗣️", title: "Elige tus idiomas", message: "Emparejamos a quien habla lo que tú aprendes y aprende lo que tú hablas.",
                      color: .lazyMint, actionTitle: "Elegir idiomas") { showLanguages = true }
        case .completeProfile:
            StateCard(emoji: "📝", title: "Completa tu perfil", message: "Necesitas al menos 2 fotos, tus datos básicos y 3 intereses.", color: .lazyNotice)
        }
    }

    private func enableMode(_ model: DeckViewModel) async {
        var payload = OnboardingPayload()
        switch active {
        case .friendship: payload.modeFriendship = true
        case .language:   payload.modeLanguage = true
        default:          payload.modeDating = true
        }
        do { try await APIClient.shared.send(.onboarding, body: payload); await model.load(reset: true) }
        catch { model.toast = Toast(text: "No se pudo activar. Revisa tu perfil.", isError: true) }
    }

    // MARK: - Acciones

    private func actions(_ model: DeckViewModel) -> some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 16) {
                GlassCircleButton(systemImage: "arrow.uturn.backward", tint: .lazyYellow, size: 50, isEnabled: model.canRewind,
                                  accessibilityLabel: "Deshacer") {
                    if store.isPremium { Task { await model.rewind() } } else { paywallReason = .rewind }
                }
                GlassCircleButton(systemImage: "xmark", tint: .lazyRed, size: 66, accessibilityLabel: "No me interesa") { command = .pass }
                GlassCircleButton(systemImage: "star.fill", tint: .lazyCyan, size: 50, accessibilityLabel: "Superlike") {
                    if store.isPremium { command = .superlike } else { paywallReason = .superlike }
                }
                GlassCircleButton(systemImage: "heart.fill", tint: .lazyMint, size: 66, accessibilityLabel: "Me gusta") { command = .like }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func celebration(_ model: DeckViewModel) -> some View {
        if let match = model.newMatch {
            MatchCelebrationView(match: match, myPhoto: account.firstPhotoURL, myName: account.displayName,
                                 onMessage: { model.dismissMatch(); chatMatch = match },
                                 onKeepSwiping: { model.dismissMatch() })
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
        }
    }
}
