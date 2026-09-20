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
    /// La peticion en vuelo, para que dos pantallas que arrancan a la vez
    /// esperen a la MISMA y no se pisen.
    private var inFlight: Task<MeResponse?, Never>?

    init(api: any APIService = APIClient.shared) { self.api = api }

    var userID: String? { me?.user.id }
    var firstPhotoURL: URL? { me?.photos?.compactMap(\.thumbURL).first }
    var displayName: String { me?.profile?.displayName ?? "Yo" }

    /// Antes, quien llegaba segundo se iba de vacio (`guard !isLoading else
    /// { return me }`) en vez de esperar. Al abrir la app, el mazo y la lista
    /// de chats piden la cuenta a la vez: el segundo recibia `nil`, y de ahi
    /// salia el "No se pudo abrir el chat" con la red perfectamente bien.
    @discardableResult
    func refresh() async -> MeResponse? {
        if let inFlight { return await inFlight.value }

        let task = Task<MeResponse?, Never> { [api] in
            if let response: MeResponse = try? await api.send(.me) {
                me = response
                StoreService.shared.apply(premium: response.user.premium ?? false, until: response.user.premiumUntil)
            }
            return me
        }
        inFlight = task
        isLoading = true
        defer { inFlight = nil; isLoading = false }
        return await task.value
    }

    /// Devuelve el id propio, cargando la cuenta si hace falta.
    func requireUserID() async -> String? {
        if let userID { return userID }
        return await refresh()?.user.id
    }

    func clear() {
        inFlight?.cancel()
        inFlight = nil
        me = nil
    }
}
