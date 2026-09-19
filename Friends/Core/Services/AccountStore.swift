import Foundation

/// La cuenta propia (GET /me), compartida por el mazo, el chat y el perfil.
/// Es la unica fuente de "quien soy" y de si soy premium.
@MainActor
@Observable
final class AccountStore {
    static let shared = AccountStore()

    private(set) var me: MeResponse?
    private(set) var isLoading = false

    private let api: any APIService
    init(api: any APIService = APIClient.shared) { self.api = api }

    var userID: String? { me?.user.id }
    var firstPhotoURL: URL? { me?.photos?.compactMap(\.thumbURL).first }
    var displayName: String { me?.profile?.displayName ?? "Yo" }

    @discardableResult
    func refresh() async -> MeResponse? {
        guard !isLoading else { return me }
        isLoading = true
        defer { isLoading = false }
        if let response: MeResponse = try? await api.send(.me) {
            me = response
            StoreService.shared.apply(premium: response.user.premium ?? false, until: response.user.premiumUntil)
        }
        return me
    }

    /// Devuelve el id propio, cargando la cuenta si hace falta.
    func requireUserID() async -> String? {
        if let userID { return userID }
        return await refresh()?.user.id
    }

    func clear() { me = nil }
}
