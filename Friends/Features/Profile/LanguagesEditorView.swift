import SwiftUI

/// Idiomas que hablo y que aprendo, con nivel CEFR. Sirve al intercambio de idiomas:
/// solo se empareja con quien habla lo que yo aprendo Y aprende lo que yo hablo.
struct LanguagesEditorView: View {
    var api: any APIService = APIClient.shared
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var catalog: [LanguageItem] = []
    @State private var native: Set<String> = []
    @State private var learning: [String: String] = [:]     // language_id -> nivel
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let levels = ["a1", "a2", "b1", "b2", "c1", "c2"]

    var body: some View {
        NavigationStack {
            ZStack {
                DoodleBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        block("🗣️ Hablo (nativo)", "Elige al menos uno.") {
                            ChipFlow {
                                ForEach(catalog) { language in
                                    ChoiceChip(label: language.name, selectedColor: .lazyMint, isSelected: native.contains(language.id)) {
                                        if native.contains(language.id) { native.remove(language.id) }
                                        else { native.insert(language.id); learning[language.id] = nil }
                                    }
                                }
                            }
                        }

                        block("📖 Estoy aprendiendo", "Con tu nivel actual.") {
                            ChipFlow {
                                ForEach(catalog.filter { !native.contains($0.id) }) { language in
                                    ChoiceChip(label: language.name, selectedColor: .lazyYellow, isSelected: learning[language.id] != nil) {
                                        learning[language.id] = learning[language.id] == nil ? "a2" : nil
                                    }
                                }
                            }
                            ForEach(catalog.filter { learning[$0.id] != nil }) { language in
                                HStack {
                                    Text(language.name).font(.lazySubhead)
                                    Spacer()
                                    Picker("Nivel", selection: Binding(get: { learning[language.id] ?? "a2" }, set: { learning[language.id] = $0 })) {
                                        ForEach(levels, id: \.self) { Text($0.uppercased()).tag($0) }
                                    }
                                    .pickerStyle(.menu).tint(Color.lazyBlack)
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.lazyCaption).foregroundStyle(Color.lazyBlack)
                                .padding(12).lazyCard(backgroundColor: .lazyNotice, cornerRadius: 12, offset: 3).stickerPadding()
                        }
                    }
                    .padding(22).padding(.bottom, 30)
                }
            }
            .navigationTitle("Idiomas").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(native.isEmpty || isSaving)
                }
            }
        }
        .task { await load() }
    }

    private func block<Content: View>(_ title: String, _ hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.lazySubhead)
            Text(hint).font(.lazyCaption).foregroundStyle(.secondary)
            content()
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .lazyCard().stickerPadding()
    }

    private func load() async {
        if let response: LanguagesResponse = try? await api.send(.languages) { catalog = response.languages }
        if let me: MeResponse = try? await api.send(.me) {
            for entry in me.languages ?? [] {
                if entry.kind == "native" { native.insert(entry.languageId) }
                else { learning[entry.languageId] = entry.level ?? "a2" }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var payload = OnboardingPayload()
        payload.languages = native.map { LanguageEntry(languageId: $0, kind: "native", level: nil) }
            + learning.map { LanguageEntry(languageId: $0.key, kind: "learning", level: $0.value) }
        do {
            try await api.send(.onboarding, body: payload)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "No se pudieron guardar tus idiomas."
        }
    }
}
