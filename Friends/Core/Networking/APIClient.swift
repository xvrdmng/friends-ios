import Foundation

/// Cliente HTTP del API de Friends.
///
/// Evoluciona el `APIClient` de toolazytooplay-ios, que era anónimo y de solo
/// lectura: aquí se añaden verbos con cuerpo, la cabecera Authorization desde el
/// Keychain, y el cierre de sesión automático ante un 401.
final class APIClient: Sendable {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = URL(string: "http://localhost:3000")!
    #else
    private let baseURL = URL(string: "https://api.toolazy.cl")!
    #endif

    private let session: URLSession
    private let sessionStore: SessionStore

    init(sessionStore: SessionStore = .shared) {
        self.sessionStore = sessionStore

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 10 << 20, diskCapacity: 50 << 20)
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }

    // MARK: - Peticiones

    @discardableResult
    func send<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: (any Encodable & Sendable)? = nil
    ) async throws -> Response {
        let request = try await buildRequest(endpoint, body: body)
        let data = try await execute(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func send(_ endpoint: APIEndpoint, body: (any Encodable & Sendable)? = nil) async throws {
        let request = try await buildRequest(endpoint, body: body)
        _ = try await execute(request)
    }

    private func buildRequest(
        _ endpoint: APIEndpoint,
        body: (any Encodable & Sendable)?
    ) async throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )!
        if !endpoint.queryItems.isEmpty { components.queryItems = endpoint.queryItems }
        guard let url = components.url else { throw APIError.unknown }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages.first ?? "es", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        request.cachePolicy = endpoint.isCacheable ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData

        if let token = await sessionStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            // El token ya no vale: se descarta y la app vuelve a la pantalla de passkey.
            await sessionStore.clear()
            throw APIError.unauthorized
        default:
            if let payload = try? decoder.decode(APIErrorPayload.self, from: data) {
                throw APIError.server(code: payload.error.code, message: payload.error.message)
            }
            throw APIError.http(status: http.statusCode)
        }
    }
}
