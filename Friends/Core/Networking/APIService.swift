import Foundation

/// Lo que los view models necesitan de la red. Existe para poder probarlos con una
/// API falsa: `APIClient` la implementa y los tests inyectan un doble.
protocol APIService: Sendable {
    func send<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint, body: (any Encodable & Sendable)?, snakeCase: Bool
    ) async throws -> Response

    func send(_ endpoint: APIEndpoint, body: (any Encodable & Sendable)?, snakeCase: Bool) async throws

    func upload<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint, field: String, data: Data, filename: String, mimeType: String, fields: [String: String]
    ) async throws -> Response
}

extension APIService {
    func send<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint, body: (any Encodable & Sendable)? = nil
    ) async throws -> Response {
        try await send(endpoint, body: body, snakeCase: true)
    }

    func send(_ endpoint: APIEndpoint, body: (any Encodable & Sendable)? = nil) async throws {
        try await send(endpoint, body: body, snakeCase: true)
    }
}

extension APIClient: APIService {}
