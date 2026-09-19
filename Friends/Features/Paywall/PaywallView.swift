import StoreKit
import SwiftUI

/// Por que se abrio el paywall: cambia el titular, no el resto.
enum PaywallReason: String, Identifiable {
    case likeLimit, superlike, rewind, filters, likesReceived, radius, generic

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .likeLimit:     "Se acabaron los likes de hoy"
        case .superlike:     "Los superlikes son premium"
        case .rewind:        "Deshacer es premium"
        case .filters:       "Filtros avanzados"
        case .likesReceived: "Descubre a quién le gustas"
        case .radius:        "Más allá de 100 km"
        case .generic:       "Friends Premium"
        }
    }
}

struct PaywallView: View {
    var reason: PaywallReason = .generic
    var api: any APIService = APIClient.shared

    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreService.shared
    @State private var selectedID = StoreService.yearlyID
    @State private var isRestoring = false

    private let benefits: [(symbol: String, text: String)] = [
        ("infinity", "Likes ilimitados"),
        ("eye", "Ve quién te dio like"),
        ("arrow.uturn.backward", "Deshacer tu último swipe"),
        ("star", "Un superlike al día"),
        ("globe", "Radio de búsqueda sin límite"),
        ("line.3.horizontal.decrease", "Filtros avanzados")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heading
                    benefitList
                    plans
                    if let message = store.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    purchaseButton
                    Button(isRestoring ? "Restaurando…" : "Restaurar compras") { Task { await restore() } }
                        .font(.footnote)

                    #if DEBUG
                    Button("Activar premium (solo desarrollo)") { Task { await devPremium() } }
                        .font(.caption)
                        .foregroundStyle(.red)
                    #endif

                    legal
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .task {
            await store.loadProducts()
            if let yearly = store.products.first(where: { $0.id == StoreService.yearlyID }) { selectedID = yearly.id }
            else if let first = store.products.first { selectedID = first.id }
        }
        .onChange(of: store.isPremium) { _, premium in if premium { dismiss() } }
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
            Text(reason.headline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Friends Premium")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.text) { item in
                Label(item.text, systemImage: item.symbol)
                    .font(.body)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            ContentUnavailableView {
                Label("Los planes no están disponibles ahora", systemImage: "cart")
            } description: {
                Text("Revisa tu conexión e inténtalo de nuevo.")
            } actions: {
                Button("Reintentar") { Task { await store.loadProducts() } }
                    .buttonStyle(.glassProminent)
            }
        } else {
            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let selected = product.id == selectedID
        let isYearly = product.id == StoreService.yearlyID
        return Button { selectedID = product.id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isYearly ? "Anual" : "Mensual").font(.headline)
                    Text(isYearly ? "El mejor precio" : "Cancela cuando quieras")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice).font(.headline)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var purchaseButton: some View {
        Button(store.isPurchasing ? "Procesando…" : "Continuar") { Task { await buy() } }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(store.isPurchasing || store.products.isEmpty)
    }

    private var legal: some View {
        VStack(spacing: 8) {
            Text("La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes del fin del período. Gestiona o cancela en los Ajustes de tu cuenta de Apple.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Link("Términos de uso", destination: URL(string: "https://toolazy.cl/friends/terminos")!)
                Link("Privacidad", destination: URL(string: "https://toolazy.cl/friends/privacidad")!)
            }
            .font(.caption2)
        }
    }

    private func buy() async {
        guard let product = store.products.first(where: { $0.id == selectedID }) else { return }
        await store.purchase(product)
    }

    private func restore() async {
        isRestoring = true
        await store.restore()
        isRestoring = false
    }

    #if DEBUG
    private func devPremium() async {
        if let response: SubscriptionResponse = try? await api.send(.devPremium, body: EnabledRequest(enabled: true)) {
            store.apply(premium: response.premium, until: response.premiumUntil)
        }
    }
    #endif
}
