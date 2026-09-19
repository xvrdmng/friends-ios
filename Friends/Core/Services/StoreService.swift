import Foundation
import StoreKit

/// Compras con StoreKit 2.
///
/// La app NUNCA decide sola si alguien es premium: cada transaccion se manda como
/// JWS firmado por Apple a `/subscriptions/sync` y el servidor la verifica contra la
/// raiz de Apple. Aqui `isPremium` solo refleja lo que el servidor confirma.
@MainActor
@Observable
final class StoreService {
    static let shared = StoreService()

    static let monthlyID = "cl.toolazy.friends.premium.monthly"
    static let yearlyID  = "cl.toolazy.friends.premium.yearly"
    static let productIDs = [monthlyID, yearlyID]

    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    private(set) var isPremium = false
    private(set) var premiumUntil: Date?
    var errorMessage: String?

    private let api: any APIService
    private var listener: Task<Void, Never>?

    init(api: any APIService = APIClient.shared) { self.api = api }

    /// Escucha renovaciones y compras hechas fuera de la app. Llamar una vez al iniciar.
    func start() {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refreshFromServer() }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
        } catch {
            errorMessage = "No se pudieron cargar los planes."
        }
    }

    func refreshFromServer() async {
        guard let me: MeResponse = try? await api.send(.me) else { return }
        apply(premium: me.user.premium ?? false, until: me.user.premiumUntil)
    }

    func apply(premium: Bool, until: Date? = nil) {
        isPremium = premium
        premiumUntil = until
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            var options: Set<Product.PurchaseOption> = []
            // El servidor usa este id para saber de quien es la compra (webhook incluido).
            if let me: MeResponse = try? await api.send(.me), let uuid = UUID(uuidString: me.user.id) {
                options.insert(.appAccountToken(uuid))
            }
            switch try await product.purchase(options: options) {
            case .success(let verification):
                return await handle(verification)
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "La compra quedó pendiente de aprobación."
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "No se pudo completar la compra."
            return false
        }
    }

    /// Recupera compras hechas con la misma cuenta de Apple (otro dispositivo, reinstalacion).
    func restore() async {
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements { await handle(result) }
            await refreshFromServer()
        } catch {
            errorMessage = "No se pudieron restaurar las compras."
        }
    }

    @discardableResult
    private func handle(_ verification: VerificationResult<Transaction>) async -> Bool {
        // Comprobacion local de StoreKit (rapida); la que vale es la del servidor.
        guard case .verified(let transaction) = verification else {
            errorMessage = "Apple no pudo verificar la compra."
            return false
        }
        do {
            let response: SubscriptionResponse = try await api.send(
                .syncSubscription, body: SyncRequest(signedTransaction: verification.jwsRepresentation)
            )
            apply(premium: response.premium, until: response.premiumUntil)
            await transaction.finish()   // solo se cierra si el servidor la acepto
            return response.premium
        } catch {
            errorMessage = "Tu compra se realizó pero no pudimos activarla aún. Reintentaremos al abrir la app."
            return false
        }
    }
}
