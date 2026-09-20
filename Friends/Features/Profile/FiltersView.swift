import SwiftUI

/// Filtros de busqueda: distancia, edad y (premium) campos avanzados.
struct FiltersView: View {
    var api: any APIService = APIClient.shared
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var filters: FiltersResponse?
    @State private var loadFailed = false
    @State private var isSaving = false
    @State private var paywallReason: PaywallReason?
    @State private var error: AlertMessage?

    private let advancedOptions: [(key: String, title: String, options: [String: String])] = [
        ("relationship_goal", "Qué busca", Labels.goal),
        ("kids", "Hijos", Labels.kids),
        ("smoking", "Fuma", Labels.smoking),
        ("drinking", "Bebe", Labels.drinking),
        ("education", "Estudios", Labels.education)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let filters {
                    form(filters)
                } else if loadFailed {
                    // Antes se quedaba girando para siempre: sin filtros y sin
                    // manera de volver a pedirlos.
                    ContentUnavailableView {
                        Label("No pudimos cargar tus filtros", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Revisa tu conexión.")
                    } actions: {
                        Button("Reintentar") { Task { await load() } }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(isSaving || filters == nil)
                }
            }
            .errorAlert($error)
            .disabled(isSaving)
        }
        .task { await load() }
        .sheet(item: $paywallReason) { reason in PaywallView(reason: reason) }
    }

    private func form(_ f: FiltersResponse) -> some View {
        Form {
            Section {
                LabeledContent("Distancia máxima", value: "\(f.distanceKm) km")
                Slider(value: Binding(get: { Double(f.distanceKm) }, set: { filters?.distanceKm = Int($0) }),
                       in: 1...Double(min(f.maxDistanceKm, 500)), step: 1)
                    .accessibilityLabel("Distancia máxima en kilómetros")
                    .accessibilityValue("\(f.distanceKm) kilómetros")
            } header: {
                Text("Distancia")
            } footer: {
                if !f.premium {
                    Button { paywallReason = .radius } label: {
                        Label("Con premium, sin límite de 100 km", systemImage: "lock.fill")
                            .font(.footnote)
                    }
                }
            }

            Section("Edad") {
                LabeledContent("Rango", value: "\(f.ageMin) a \(f.ageMax) años")
                Slider(value: Binding(get: { Double(f.ageMin) },
                                      set: { filters?.ageMin = min(Int($0), filters?.ageMax ?? 99) }),
                       in: 18...99, step: 1)
                    .accessibilityLabel("Edad mínima")
                    .accessibilityValue("\(f.ageMin) años")
                Slider(value: Binding(get: { Double(f.ageMax) },
                                      set: { filters?.ageMax = max(Int($0), filters?.ageMin ?? 18) }),
                       in: 18...99, step: 1)
                    .accessibilityLabel("Edad máxima")
                    .accessibilityValue("\(f.ageMax) años")
            }

            advancedSection(f)
        }
    }

    @ViewBuilder
    private func advancedSection(_ f: FiltersResponse) -> some View {
        Section {
            if f.premium {
                ForEach(advancedOptions, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ChipFlow {
                            ForEach(group.options.sorted { $0.value < $1.value }, id: \.key) { key, label in
                                ChoiceChip(label: label,
                                           isSelected: f.advanced[group.key]?.contains(key) == true) {
                                    toggle(group.key, key)
                                }
                            }
                        }
                    }
                }
            } else {
                Button { paywallReason = .filters } label: {
                    LabeledContent {
                        Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.tertiary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Desbloquear filtros avanzados")
                            Text("Qué busca, hijos, fuma, bebe y estudios.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Avanzados")
        }
    }

    private func toggle(_ group: String, _ value: String) {
        guard var f = filters else { return }
        var list = f.advanced[group] ?? []
        if let index = list.firstIndex(of: value) { list.remove(at: index) } else { list.append(value) }
        f.advanced[group] = list
        filters = f
    }

    private func load() async {
        loadFailed = false
        filters = try? await api.send(.filters)
        loadFailed = filters == nil
    }

    private func save() async {
        guard let f = filters, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let body = FiltersRequest(distanceKm: f.distanceKm, ageMin: f.ageMin, ageMax: f.ageMax,
                                      advanced: f.premium ? f.advanced.filter { !$0.value.isEmpty } : nil)
            let _: FiltersResponse = try await api.send(.updateFilters, body: body)
            onSaved()
            dismiss()
        } catch let error as APIError {
            if case .server(let code, let message) = error {
                if code == "premium_required" { paywallReason = .radius }
                else { self.error = AlertMessage("No se pudo guardar", message: message) }
            } else {
                self.error = AlertMessage("No se pudo guardar")
            }
        } catch {
            self.error = AlertMessage("No se pudo guardar")
        }
    }
}
