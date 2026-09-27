import AuthenticationServices
import Foundation
import UIKit

/// Alta e inicio de sesión con passkey.
///
/// El relying party es `friends-api.toolazy.cl`, el mismo host del API, que sirve el
/// archivo de asociación que Apple necesita. Cambiarlo más adelante invalidaría
/// todas las passkeys ya emitidas.
@MainActor
final class PasskeyService: NSObject {
    static let relyingPartyIdentifier = "friends-api.toolazy.cl"

    private var continuation: CheckedContinuation<ASAuthorization, any Error>?

    /// Crea una passkey nueva (registro).
    func register(challenge: Data, userID: Data, name: String) async throws -> ASAuthorization {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: Self.relyingPartyIdentifier
        )
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: name,
            userID: userID
        )
        return try await perform([request], preferImmediate: false)
    }

    /// Inicia sesión con una passkey existente (discoverable: sin allowCredentials).
    func signIn(challenge: Data, preferImmediate: Bool = true) async throws -> ASAuthorization {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: Self.relyingPartyIdentifier
        )
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        return try await perform([request], preferImmediate: preferImmediate)
    }

    private func perform(
        _ requests: [ASAuthorizationRequest],
        preferImmediate: Bool
    ) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: requests)
            controller.delegate = self
            controller.presentationContextProvider = self
            if preferImmediate {
                controller.performRequests(options: .preferImmediatelyAvailableCredentials)
            } else {
                controller.performRequests()
            }
        }
    }
}

extension PasskeyService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension PasskeyService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            guard let scene else {
                preconditionFailure("No hay ninguna escena activa para presentar la passkey")
            }
            return scene.keyWindow ?? ASPresentationAnchor(windowScene: scene)
        }
    }
}
