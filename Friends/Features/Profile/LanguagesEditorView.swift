import SwiftUI

/// Idiomas que hablo y que aprendo. Sirve al intercambio de
/// idiomas: solo se empareja con quien habla lo que yo aprendo Y aprende lo que
/// yo hablo.
struct LanguagesEditorView: View {
    var api: any APIService = APIClient.shared
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var catalog: [LanguageItem] = []
    @State private var native: Set<String> = []
    // language_id -> nivel. No se muestra: el servidor lo exige para lo que aprendes,
    // asi que se conserva el que ya hubiera y si no se manda a1.
    @State private var learning: [String: String] = [:]
    @State private var isSaving = false
    @State private var error: AlertMessage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ChipFlow {
                        ForEach(catalog) { language in
                            ChoiceChip(label: language.name, isSelected: native.contains(language.id)) {
                                if native.contains(language.id) { native.remove(language.id) }
                                else { native.insert(language.id); learning[language.id] = nil }
                            }
                        }
                    }
                } header: {
                    Text("Idiomas nativos")
                } footer: {
                    Text("Elige al menos uno.")
                }

                Section("Idiomas que quiero aprender") {
                    ChipFlow {
                        ForEach(catalog.filter { !native.contains($0.id) }) { language in
                            ChoiceChip(label: language.name, isSelected: learning[language.id] != nil) {
                                learning[language.id] = learning[language.id] == nil ? "a1" : nil
                            }
                        }
                    }
                }
            }
            .navigationTitle("Idiomas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(native.isEmpty || isSaving)
                }
            }
            .errorAlert($error)
            .disabled(isSaving)
        }
        .task { await load() }
    }

    private func load() async {
        if let response: LanguagesResponse = try? await api.send(.languages) { catalog = response.languages }
        if let me: MeResponse = try? await api.send(.me) {
            for entry in me.languages ?? [] {
                if entry.kind == "native" { native.insert(entry.languageId) }
                else { learning[entry.languageId] = entry.level ?? "a1" }
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
            self.error = AlertMessage("No se pudieron guardar tus idiomas")
        }
    }
}
