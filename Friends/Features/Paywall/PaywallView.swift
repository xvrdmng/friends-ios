import StoreKit
import SwiftUI

/// Por que se abrio el paywall: cambia el titular, no el resto.
enum PaywallReason {
    case likeLimit, superlike, rewind, filters, likesReceived, radius, generic

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

    private let benefits: [(emoji: String, text: String)] = [
        ("♾️", "Likes ilimitados"), ("👀", "Ve quién te dio like"), ("↩️", "Deshacer tu último swipe"),
        ("⭐", "Un superlike al día"), ("🌎", "Radio de búsqueda sin límite"), ("🎛️", "Filtros avanzados")
    ]

    var body: some View {
        ZStack {
            DoodleBackground()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("👑").font(.system(size: 54))
                        Text(reason.headline).font(.lazyHeading).multilineTextAlignment(.center)
                        Text("Friends Premium").font(.lazyMono).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Color.lazyBlack)
                    .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(benefits, id: \.text) { item in
                            HStack(spacing: 12) {
                                Text(item.emoji).font(.system(size: 22))
                                Text(item.text).font(.lazySubhead)
                            }
                        }
                    }
                    .foregroundStyle(Color.lazyBlack)
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .lazyCard(backgroundColor: .lazyYellow).stickerPadding()

                    plans

                    if let message = store.errorMessage {
                        Text(message).font(.lazyCaption).foregroundStyle(Color.lazyBlack)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .lazyCard(backgroundColor: .lazyNotice, cornerRadius: 12, offset: 3).stickerPadding()
                    }

                    Button(store.isPurchasing ? "Procesando…" : "Continuar") { Task { await buy() } }
                        .buttonStyle(LazyButtonStyle(background: .lazyRose, foreground: .lazyBlack, fillsWidth: true))
                        .disabled(store.isPurchasing || store.products.isEmpty)
                        .stickerPadding()

                    Button(isRestoring ? "Restaurando…" : "Restaurar compras") { Task { await restore() } }
                        .font(.lazyCaption).foregroundStyle(Color.lazyBlack)

                    #if DEBUG
                    Button("Activar premium (solo desarrollo)") { Task { await devPremium() } }
                        .font(.lazyMono).foregroundStyle(Color.lazyRed)
                    #endif

                    legal
                }
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.lazyBlack).frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .padding(16).accessibilityLabel("Cerrar")
        }
        .task {
            await store.loadProducts()
            if let yearly = store.products.first(where: { $0.id == StoreService.yearlyID }) { selectedID = yearly.id }
            else if let first = store.products.first { selectedID = first.id }
        }
        .onChange(of: store.isPremium) { _, premium in if premium { dismiss() } }
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            StateCard(emoji: "🛒", title: "Los planes no están disponibles ahora",
                      message: "Revisa tu conexión e inténtalo de nuevo.",
                      actionTitle: "Reintentar") { Task { await store.loadProducts() } }
        } else {
            VStack(spacing: 14) {
                ForEach(store.products, id: \.id) { product in
                    let selected = product.id == selectedID
                    Button { selectedID = product.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.id == StoreService.yearlyID ? "Anual" : "Mensual").font(.lazySubhead)
                                Text(product.id == StoreService.yearlyID ? "El mejor precio" : "Cancela cuando quieras")
                                    .font(.lazyCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice).font(.lazySubhead)
                        }
                        .foregroundStyle(Color.lazyBlack)
                        .padding(18)
                        .lazyCard(backgroundColor: selected ? .lazyMint : .white, offset: selected ? 2 : 4)
                        .offset(x: selected ? 2 : 0, y: selected ? 2 : 0)
                        .stickerPadding()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var legal: some View {
        VStack(spacing: 6) {
            Text("La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes del fin del período. Gestiona o cancela en los Ajustes de tu cuenta de Apple.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Link("Términos de uso", destination: URL(string: "https://toolazy.cl/friends/terminos")!)
                Link("Privacidad", destination: URL(string: "https://toolazy.cl/friends/privacidad")!)
            }
            .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.lazyBlack)
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
