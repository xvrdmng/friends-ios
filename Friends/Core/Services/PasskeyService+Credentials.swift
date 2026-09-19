import AuthenticationServices
import Foundation

/// Traduce el resultado de ASAuthorization al JSON que espera webauthn-ruby.
extension PasskeyService {
    enum CredentialError: Error, LocalizedError {
        case unexpectedCredentialType
        case invalidChallenge

        var errorDescription: String? {
            switch self {
            case .unexpectedCredentialType: "El sistema devolvio un tipo de credencial inesperado."
            case .invalidChallenge:         "El reto del servidor no es valido."
            }
        }
    }

    static func challengeData(from base64URL: String) throws -> Data {
        guard let data = Base64URL.decode(base64URL) else { throw CredentialError.invalidChallenge }
        return data
    }

    /// Alta: attestationObject + clientDataJSON.
    static func payload(
        from registration: ASAuthorizationPlatformPublicKeyCredentialRegistration
    ) -> CredentialPayload {
        let id = Base64URL.encode(registration.credentialID)
        return CredentialPayload(
            id: id,
            rawId: id,
            type: "public-key",
            response: .init(
                clientDataJSON: Base64URL.encode(registration.rawClientDataJSON),
                attestationObject: registration.rawAttestationObject.map(Base64URL.encode)
            )
        )
    }

    /// Login: authenticatorData + signature + userHandle.
    static func payload(
        from assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion
    ) -> CredentialPayload {
        let id = Base64URL.encode(assertion.credentialID)
        return CredentialPayload(
            id: id,
            rawId: id,
            type: "public-key",
            response: .init(
                clientDataJSON: Base64URL.encode(assertion.rawClientDataJSON),
                authenticatorData: Base64URL.encode(assertion.rawAuthenticatorData),
                signature: Base64URL.encode(assertion.signature),
                userHandle: assertion.userID.map(Base64URL.encode)
            )
        )
    }
}
