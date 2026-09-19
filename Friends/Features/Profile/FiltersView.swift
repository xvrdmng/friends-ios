import SwiftUI

/// Filtros de busqueda: distancia, edad y (premium) campos avanzados.
struct FiltersView: View {
    var api: any APIService = APIClient.shared
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var filters: FiltersResponse?
    @State private var isSaving = false
    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .filters
    @State private var toast: Toast?

    private let advancedOptions: [(key: String, title: String, options: [String: String])] = [
        ("relationship_goal", "Qué busca", Labels.goal),
        ("kids", "Hijos", Labels.kids),
        ("smoking", "Fuma", Labels.smoking),
        ("drinking", "Bebe", Labels.drinking),
        ("education", "Estudios", Labels.education)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DoodleBackground()
                if let filters { content(filters) } else { ProgressView() }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(isSaving || filters == nil)
                }
            }
            .toast($toast)
        }
        .task { await load() }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: paywallReason) }
    }

    private func content(_ f: FiltersResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Distancia máxima") {
                    Text("\(f.distanceKm) km").font(.lazySubhead)
                    Slider(value: Binding(get: { Double(f.distanceKm) }, set: { filters?.distanceKm = Int($0) }),
                           in: 1...Double(min(f.maxDistanceKm, 500)), step: 1)
                        .tint(Color.lazyRose)
                    if !f.premium {
                        Button { paywallReason = .radius; showPaywall = true } label: {
                            Label("Con premium, sin límite de 100 km", systemImage: "lock.fill").font(.lazyCaption)
                        }
                        .foregroundStyle(Color.lazyBlack)
                    }
                }

                section("Edad") {
                    Text("\(f.ageMin) a \(f.ageMax) años").font(.lazySubhead)
                    Slider(value: Binding(get: { Double(f.ageMin) }, set: { filters?.ageMin = min(Int($0), filters?.ageMax ?? 99) }),
                           in: 18...99, step: 1).tint(Color.lazyRose)
                    Slider(value: Binding(get: { Double(f.ageMax) }, set: { filters?.ageMax = max(Int($0), filters?.ageMin ?? 18) }),
                           in: 18...99, step: 1).tint(Color.lazyRose)
                }

                section("Avanzados", locked: !f.premium) {
                    ForEach(advancedOptions, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title.uppercased()).font(.lazyMono).foregroundStyle(.secondary)
                            ChipFlow {
                                ForEach(group.options.sorted { $0.value < $1.value }, id: \.key) { key, label in
                                    ChoiceChip(label: label, selectedColor: .lazyMint,
                                               isSelected: f.advanced[group.key]?.contains(key) == true) {
                                        toggle(group.key, key)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(22).padding(.bottom, 40)
        }
    }

    private func section<Content: View>(_ title: String, locked: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased()).font(.lazyMono)
                if locked { Tag(text: "Premium", color: .lazyYellow) }
            }
            content()
        }
        .foregroundStyle(Color.lazyBlack)
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .lazyCard().stickerPadding()
        .opacity(locked ? 0.55 : 1)
        .overlay {
            if locked { Color.clear.contentShape(Rectangle()).onTapGesture { paywallReason = .filters; showPaywall = true } }
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
        filters = try? await api.send(.filters)
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
                if code == "premium_required" { paywallReason = .radius; showPaywall = true }
                else { toast = Toast(text: message, isError: true) }
            } else { toast = Toast(text: "No se pudo guardar", isError: true) }
        } catch {
            toast = Toast(text: "No se pudo guardar", isError: true)
        }
    }
}
