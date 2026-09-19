import Foundation
import Security

/// Guarda el token de sesión en el Keychain.
///
/// El token es opaco (32 bytes generados por el servidor), no un JWT: así se puede
/// revocar desde el back-office. Accesible solo tras el primer desbloqueo y sin
/// sincronizar a iCloud, porque está atado a este dispositivo.
actor SessionStore {
    static let shared = SessionStore()

    private let service = "cl.toolazy.friends.session"
    private let account = "token"
    private var cached: String?

    var token: String? {
        if let cached { return cached }
        cached = read()
        return cached
    }

    var isSignedIn: Bool { token != nil }

    func store(_ token: String) {
        cached = token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        cached = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
