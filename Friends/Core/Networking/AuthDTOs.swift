import Foundation

// MARK: - Base64URL
//
// WebAuthn habla base64url sin relleno en todas partes: el reto que manda el
// servidor, el id de la credencial y cada campo de la respuesta.

enum Base64URL {
    static func decode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: s)
    }

    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Respuestas del servidor

/// Lo que devuelven /auth/registration/options y /auth/session/options.
/// Del bloque public_key solo se necesita el challenge: el resto de la
/// configuracion (rp, algoritmos, user verification) la aplica iOS desde el
/// entitlement y la peticion que construimos.
struct ChallengeResponse: Decodable, Sendable {
    let challengeToken: String
    let publicKey: PublicKey

    struct PublicKey: Decodable, Sendable {
        let challenge: String
        let user: UserInfo?

        struct UserInfo: Decodable, Sendable {
            let id: String
            let name: String
        }
    }
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let expiresAt: Date
    let user: UserSummary

    struct UserSummary: Decodable, Sendable {
        let id: String
        let handle: String
        let onboardingCompleted: Bool
    }
}

// MARK: - Peticiones

/// La credencial se manda con la forma que espera webauthn-ruby
/// (`WebAuthn::Credential.from_create` / `from_get`).
struct CredentialPayload: Encodable, Sendable {
    let id: String
    let rawId: String
    let type: String
    let response: Response

    struct Response: Encodable, Sendable {
        var clientDataJSON: String
        var attestationObject: String?   // solo en alta
        var authenticatorData: String?   // solo en login
        var signature: String?
        var userHandle: String?
    }

    // El encoder del APIClient pasa a snake_case, pero WebAuthn exige estas
    // claves en camelCase exacto, asi que se declaran explicitamente.
    enum CodingKeys: String, CodingKey { case id, rawId, type, response }
}

struct CredentialSubmission: Encodable, Sendable {
    let challengeToken: String
    let credential: CredentialPayload
    let deviceName: String?

    enum CodingKeys: String, CodingKey {
        case challengeToken = "challenge_token"
        case credential
        case deviceName = "device_name"
    }
}

#if DEBUG
struct DevSessionRequest: Encodable, Sendable {
    let handle: String
}
#endif
