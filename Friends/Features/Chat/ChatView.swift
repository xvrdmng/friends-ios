import PhotosUI
import SwiftUI

/// Conversacion. Se presenta a pantalla completa (fullScreenCover) para quedar por
/// encima de la barra flotante de pestanas.
struct ChatView: View {
    let match: Match
    let myID: String
    var onClose: (_ unmatched: Bool) -> Void = { _ in }

    @State private var model: ChatViewModel
    @State private var report: ReportTarget?
    @State private var confirmUnmatch = false
    @State private var confirmBlock = false
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focused: Bool
    @Environment(\.scenePhase) private var scenePhase

    init(match: Match, myID: String, onClose: @escaping (Bool) -> Void = { _ in }) {
        self.match = match
        self.myID = myID
        self.onClose = onClose
        _model = State(initialValue: ChatViewModel(match: match, myID: myID))
    }

    var body: some View {
        ZStack {
            DoodleBackground()
            VStack(spacing: 0) {
                header
                if model.isClosed { closedState } else { messageList }
            }
        }
        .safeAreaInset(edge: .bottom) { if !model.isClosed { inputBar } }
        .task { await model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refresh() } } }
        .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
        .sheet(item: $report) { target in
            ReportSheet(target: target) { didBlock in if didBlock { onClose(true) } }
        }
        .confirmationDialog("¿Deshacer el match con \(match.other.displayName)?", isPresented: $confirmUnmatch, titleVisibility: .visible) {
            Button("Deshacer match", role: .destructive) { Task { if await model.unmatch() { onClose(true) } } }
        } message: { Text("La conversación se cerrará para los dos.") }
        .confirmationDialog("¿Bloquear a \(match.other.displayName)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Bloquear", role: .destructive) { Task { if await SafetyActions.block(userID: match.other.userId) { onClose(true) } } }
        } message: { Text("No podrán verse ni escribirse.") }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: 12) {
            Button { onClose(false) } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
            }
            .accessibilityLabel("Volver")

            AvatarView(url: match.other.thumbUrl, name: match.other.displayName, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.other.displayName).font(.lazySubhead).foregroundStyle(Color.lazyBlack)
                Text(model.otherIsTyping ? "escribiendo…" : (match.group?.name ?? Labels.contexts[match.context] ?? ""))
                    .font(.lazyMono).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Reportar", systemImage: "flag") {
                    report = ReportTarget(kind: .user, id: match.other.userId, userID: match.other.userId, displayName: match.other.displayName)
                }
                Button("Bloquear", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                Button("Deshacer match", systemImage: "heart.slash", role: .destructive) { confirmUnmatch = true }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
            }
            .accessibilityLabel("Más opciones")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: - Mensajes

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.hasMore {
                        Button(model.isLoadingOlder ? "Cargando…" : "Cargar anteriores") { Task { await model.loadOlder() } }
                            .font(.lazyMono).foregroundStyle(.secondary).padding(.vertical, 8)
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
            .onChange(of: focused) { Task { try? await Task.sleep(for: .milliseconds(250)); withAnimation { proxy.scrollTo("bottom") } } }
            .onChange(of: model.isLoading) { _, loading in if !loading { proxy.scrollTo("bottom") } }
        }
    }

    private var lastMineID: String? { model.messages.last(where: \.mine)?.id }

    private func showsDay(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(model.messages[index].createdAt, inSameDayAs: model.messages[index - 1].createdAt)
    }

    private func dayLabel(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary).padding(.vertical, 8)
    }

    private var emptyChat: some View {
        StateCard(emoji: "👋", title: "Rompe el hielo", message: "Es un match con \(match.other.displayName). Escríbele algo.", color: .lazyMint)
            .padding(.top, 30)
    }

    private func bubble(_ message: ChatMessage, isLastMine: Bool) -> some View {
        let state = message.clientId.flatMap { model.sendStates[$0] }
        return VStack(alignment: message.mine ? .trailing : .leading, spacing: 3) {
            HStack {
                if message.mine { Spacer(minLength: 50) }
                content(of: message)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(Color.lazyBlack)
                    .lazyCard(backgroundColor: message.mine ? .lazyRose : .white, cornerRadius: 18, offset: 3)
                    .padding(.trailing, 3).padding(.bottom, 3)
                    .opacity(state == .sending ? 0.6 : 1)
                    .contextMenu {
                        if !message.mine {
                            Button("Reportar mensaje", systemImage: "flag") {
                                report = ReportTarget(kind: .message, id: message.id, userID: match.other.userId, displayName: match.other.displayName)
                            }
                        }
                        if let body = message.body { Button("Copiar", systemImage: "doc.on.doc") { UIPasteboard.general.string = body } }
                    }
                if !message.mine { Spacer(minLength: 50) }
            }
            HStack(spacing: 6) {
                if state == .failed {
                    Button { model.retry(message) } label: {
                        Label("No enviado · Reintentar", systemImage: "exclamationmark.arrow.circlepath")
                    }
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.lazyRed)
                } else if isLastMine && message.mine && state == nil {
                    Text(message.readAt != nil ? "Leído" : "Enviado")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private func content(of message: ChatMessage) -> some View {
        if message.kind == "image", let url = message.imageUrl {
            RemoteImage(url: url).frame(width: 220, height: 280).clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text(message.body ?? "").font(.lazyBody)
        }
    }

    private var typingBubble: some View {
        HStack {
            Text("•••").font(.lazyBody).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .lazyCard(cornerRadius: 16, offset: 2).padding(.trailing, 2).padding(.bottom, 2)
            Spacer()
        }
    }

    private var closedState: some View {
        StateCard(emoji: "🚪", title: "Esta conversación ya no está disponible",
                  message: "El match se deshizo o la otra persona ya no está.", actionTitle: "Volver") { onClose(true) }
            .padding(22).frame(maxHeight: .infinity)
    }

    // MARK: - Entrada

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo").font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.lazyBlack).frame(width: 46, height: 46)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("Enviar foto")

            TextField("Escribe un mensaje", text: Bindable(model).draft, axis: .vertical)
                .font(.lazyBody).lineLimit(1...5).focused($focused)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .lazyCard(cornerRadius: 22, offset: 3).padding(.trailing, 3).padding(.bottom, 3)
                .submitLabel(.send)

            Button { model.send() } label: {
                Image(systemName: "arrow.up").font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 46, height: 46)
                    .background(Color.lazyRose, in: Circle())
                    .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 3))
            }
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Enviar")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
        photoItem = nil
        model.sendImage(jpeg)
    }
}
