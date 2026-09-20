import SwiftUI

/// Conversacion. Se presenta a pantalla completa para quedar por encima de la
/// barra de pestanas.
struct ChatView: View {
    let match: Match
    let myID: String
    var onClose: (_ unmatched: Bool) -> Void = { _ in }

    @State private var model: ChatViewModel
    @State private var report: ReportTarget?
    @State private var confirm: ChatConfirm?

    /// Un solo dialogo: dos `.confirmationDialog` en la misma vista se anulan.
    private enum ChatConfirm: Identifiable {
        case unmatch, block
        var id: Self { self }

        func title(_ name: String) -> String {
            switch self {
            case .unmatch: "¿Deshacer el match con \(name)?"
            case .block:   "¿Bloquear a \(name)?"
            }
        }

        var message: String {
            switch self {
            case .unmatch: "La conversación se cerrará para los dos."
            case .block:   "No podrán verse ni escribirse."
            }
        }

        var button: String {
            switch self {
            case .unmatch: "Deshacer match"
            case .block:   "Bloquear"
            }
        }
    }
    @FocusState private var focused: Bool
    @Environment(\.scenePhase) private var scenePhase

    init(match: Match, myID: String, onClose: @escaping (Bool) -> Void = { _ in }) {
        self.match = match
        self.myID = myID
        self.onClose = onClose
        _model = State(initialValue: ChatViewModel(match: match, myID: myID))
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isClosed { closedState } else { messageList }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { if !model.isClosed { inputBar } }
            .navigationTitle(match.other.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Volver", systemImage: "chevron.left") { onClose(false) }
                }
                ToolbarItem(placement: .principal) { title }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Reportar", systemImage: "flag") {
                            report = ReportTarget(kind: .user, id: match.other.userId,
                                                  userID: match.other.userId, displayName: match.other.displayName)
                        }
                        Button("Bloquear", systemImage: "hand.raised", role: .destructive) { confirm = .block }
                        Button("Deshacer match", systemImage: "heart.slash", role: .destructive) { confirm = .unmatch }
                    } label: {
                        Label("Más opciones", systemImage: "ellipsis")
                    }
                }
            }
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
        // El view model ya apuntaba los fallos —cargar, deshacer el match, un
        // mensaje demasiado largo— pero nadie los ensenaba.
        .alert("No se pudo",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } }),
               presenting: model.errorMessage) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refresh() } } }
        .sheet(item: $report) { target in
            ReportSheet(target: target) { didBlock in if didBlock { onClose(true) } }
        }
        .confirmationDialog(confirm?.title(match.other.displayName) ?? "",
                            isPresented: Binding(get: { confirm != nil },
                                                 set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible,
                            presenting: confirm) { action in
            Button(action.button, role: .destructive) {
                switch action {
                case .unmatch: Task { if await model.unmatch() { onClose(true) } }
                case .block:   Task { if await SafetyActions.block(userID: match.other.userId) { onClose(true) } }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }

    /// El titulo lleva la foto y el estado "escribiendo…", que el titulo de
    /// navegacion por si solo no puede mostrar.
    private var title: some View {
        HStack(spacing: 8) {
            AvatarView(url: match.other.thumbUrl, name: match.other.displayName, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(match.other.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(model.otherIsTyping ? "escribiendo…" : (match.group?.name ?? Labels.contexts[match.context] ?? ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mensajes

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.hasMore {
                        Button(model.isLoadingOlder ? "Cargando…" : "Cargar anteriores") {
                            Task { await model.loadOlder() }
                        }
                        .font(.footnote)
                        .padding(.vertical, 8)
                    }
                    if model.isLoading { ProgressView().padding(.top, 40) }
                    else if model.messages.isEmpty { emptyChat }

                    ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 2) {
                            if showsDay(at: index) { dayLabel(message.createdAt) }
                            bubble(message, isLastMine: message.id == lastMineID)
                        }
                        .id(message.id)
                    }
                    if model.otherIsTyping { typingBubble }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16).padding(.top, 6)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) { withAnimation(.snappy) { proxy.scrollTo("bottom") } }
            .onChange(of: model.otherIsTyping) { withAnimation(.snappy) { proxy.scrollTo("bottom") } }
            .onChange(of: focused) {
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            .onChange(of: model.isLoading) { _, loading in if !loading { proxy.scrollTo("bottom") } }
        }
    }

    private var lastMineID: String? { model.messages.last(where: \.mine)?.id }

    private func showsDay(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(model.messages[index].createdAt,
                                        inSameDayAs: model.messages[index - 1].createdAt)
    }

    private func dayLabel(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    private var emptyChat: some View {
        ContentUnavailableView {
            Label("Rompe el hielo", systemImage: "hand.wave")
        } description: {
            Text("Es un match con \(match.other.displayName). Escríbele algo.")
        }
        .padding(.top, 30)
    }

    private func bubble(_ message: ChatMessage, isLastMine: Bool) -> some View {
        let state = message.clientId.flatMap { model.sendStates[$0] }
        return VStack(alignment: message.mine ? .trailing : .leading, spacing: 3) {
            HStack {
                if message.mine { Spacer(minLength: 50) }
                content(of: message)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(message.mine ? .white : Color.primary)
                    .background(
                        message.mine ? AnyShapeStyle(Color.accentColor)
                                     : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: .rect(cornerRadius: 20, style: .continuous)
                    )
                    .opacity(state == .sending ? 0.6 : 1)
                    .contextMenu {
                        if !message.mine {
                            Button("Reportar mensaje", systemImage: "flag") {
                                report = ReportTarget(kind: .message, id: message.id,
                                                      userID: match.other.userId,
                                                      displayName: match.other.displayName)
                            }
                        }
                        if let body = message.body {
                            Button("Copiar", systemImage: "doc.on.doc") { UIPasteboard.general.string = body }
                        }
                    }
                if !message.mine { Spacer(minLength: 50) }
            }
            status(for: message, state: state, isLastMine: isLastMine)
        }
    }

    @ViewBuilder
    private func status(for message: ChatMessage, state: ChatViewModel.SendState?, isLastMine: Bool) -> some View {
        HStack(spacing: 6) {
            if state == .failed {
                Button { model.retry(message) } label: {
                    Label("No enviado · Reintentar", systemImage: "exclamationmark.arrow.circlepath")
                }
                .font(.caption2)
                .foregroundStyle(.red)
            } else if isLastMine && message.mine && state == nil {
                Text(message.readAt != nil ? "Leído" : "Enviado")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func content(of message: ChatMessage) -> some View {
        if message.kind == "image", let url = message.imageUrl {
            RemoteImage(url: url)
                .frame(width: 220, height: 280)
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityLabel("Foto")
        } else {
            Text(message.body ?? "")
        }
    }

    private var typingBubble: some View {
        HStack {
            Text("•••")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("\(match.other.displayName) está escribiendo")
            Spacer()
        }
    }

    /// Solo aparece cerca del limite: antes no habia ninguna senal hasta que
    /// el boton dejaba de responder.
    @ViewBuilder
    private var lengthCounter: some View {
        let count = model.draft.count
        if count > ChatViewModel.maxLength - 200 {
            Text("\(count)/\(ChatViewModel.maxLength)")
                .font(.caption2)
                .foregroundStyle(count > ChatViewModel.maxLength ? .red : .secondary)
                .padding(.trailing, 60)
        }
    }

    private var closedState: some View {
        ContentUnavailableView {
            Label("Esta conversación ya no está disponible", systemImage: "door.left.hand.closed")
        } description: {
            Text("El match se deshizo o la otra persona ya no está.")
        } actions: {
            Button("Volver") { onClose(true) }
                .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Entrada

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Mensaje", text: Bindable(model).draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: .capsule)
                .submitLabel(.send)

            Button { model.send() } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Enviar")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .topTrailing) { lengthCounter }
    }
}
