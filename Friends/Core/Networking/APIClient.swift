import Foundation

/// Cliente HTTP del API de Friends.
///
/// Evoluciona el `APIClient` de toolazytooplay-ios, que era anónimo y de solo
/// lectura: aquí se añaden verbos con cuerpo, la cabecera Authorization desde el
/// Keychain, y el cierre de sesión automático ante un 401.
final class APIClient: Sendable {
    static let shared = APIClient()

    /// Se lee del Info.plist (clave APIBaseURL), que project.yml fija por
    /// configuracion. No hay variante localhost: iOS solo emite passkeys para
    /// dominios asociados por HTTPS, asi que incluso en desarrollo hay que
    /// apuntar al dominio real.
    private let baseURL: URL = {
        let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
        return URL(string: value ?? "https://api.toolazy.cl")!
    }()

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

    /// La API habla snake_case. WebAuthn es la excepcion: exige claves en camelCase
    /// exacto (`rawId`, `clientDataJSON`), asi que sus llamadas pasan
    /// `snakeCase: false`.
    private func encoder(snakeCase: Bool) -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        if snakeCase { e.keyEncodingStrategy = .convertToSnakeCase }
        return e
    }

    // MARK: - Peticiones

    @discardableResult
    func send<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: (any Encodable & Sendable)? = nil,
        snakeCase: Bool = true
    ) async throws -> Response {
        let request = try await buildRequest(endpoint, body: body, snakeCase: snakeCase)
        let data = try await execute(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func send(_ endpoint: APIEndpoint, body: (any Encodable & Sendable)? = nil, snakeCase: Bool = true) async throws {
        let request = try await buildRequest(endpoint, body: body, snakeCase: snakeCase)
        _ = try await execute(request)
    }

    /// Cuerpo sin decodificar: el export de datos (GDPR) se guarda tal cual en un fichero.
    func sendRaw(_ endpoint: APIEndpoint) async throws -> Data {
        try await execute(buildRequest(endpoint, body: nil, snakeCase: true))
    }

    /// Sube un archivo como multipart/form-data (fotos de perfil, portadas, imagenes de chat).
    @discardableResult
    func upload<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        field: String = "image",
        data: Data,
        filename: String = "foto.jpg",
        mimeType: String = "image/jpeg",
        fields: [String: String] = [:]
    ) async throws -> Response {
        var request = try await buildRequest(endpoint, body: nil, snakeCase: true)
        let boundary = "friends-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
        }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\nContent-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let responseData = try await execute(request)
        do { return try decoder.decode(Response.self, from: responseData) }
        catch { throw APIError.decoding(error) }
    }

    private func buildRequest(
        _ endpoint: APIEndpoint,
        body: (any Encodable & Sendable)?,
        snakeCase: Bool
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
            request.httpBody = try encoder(snakeCase: snakeCase).encode(body)
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


private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}
