import Foundation
@testable import Friends

/// API falsa: cada peticion se responde con el JSON que dicte el test, y queda
/// registrada para poder comprobar QUE se envio.
final class FakeAPI: APIService, @unchecked Sendable {
    struct Call { let method: String; let path: String; let query: [String: String]; let body: [String: Any] }

    typealias Handler = (Call) throws -> String?
    private let lock = NSLock()
    private var _calls: [Call] = []
    var handler: Handler = { _ in nil }

    var calls: [Call] { lock.withLock { _calls } }
    func calls(matching path: String) -> [Call] { calls.filter { $0.path.hasSuffix(path) } }

    /// Uno nuevo por llamada, no uno compartido: hay view models que piden dos
    /// cosas a la vez con `async let`, y `JSONDecoder` no aguanta que lo usen
    /// dos hilos al mismo tiempo (revienta el proceso de pruebas entero).
    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; d.dateDecodingStrategy = .iso8601; return d
    }

    /// Ojo: hay que llamarlo YA con el cerrojo cogido.
    private func appendCall(_ endpoint: APIEndpoint, _ body: (any Encodable & Sendable)?) -> Call {
        var dict: [String: Any] = [:]
        if let body {
            let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
            if let data = try? encoder.encode(body), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] { dict = object }
        }
        let query = Dictionary(uniqueKeysWithValues: endpoint.queryItems.compactMap { item in item.value.map { (item.name, $0) } })
        let call = Call(method: endpoint.method.rawValue, path: endpoint.path, query: query, body: dict)
        _calls.append(call)
        return call
    }

    /// Todo el camino —apuntar la llamada, pedirle la respuesta al handler y
    /// decodificarla— va dentro del MISMO cerrojo, porque hay view models que
    /// piden dos cosas a la vez con `async let` y entonces esto corre en dos
    /// hilos: sin el cerrojo, `handler` y `_calls` se leerian a la vez.
    ///
    /// Ojo con lo que el test mete en `handler`: corre FUERA del main actor.
    /// Un closure que capture el XCTestCase (basta con escribir `Self.algo`
    /// dentro) tumba el proceso de pruebas entero, sin fallar ningun assert.
    private func respond<Response: Decodable>(_ endpoint: APIEndpoint,
                                              _ body: (any Encodable & Sendable)?) throws -> Response {
        try lock.withLock {
            let call = appendCall(endpoint, body)
            guard let json = try handler(call) else { throw APIError.http(status: 404) }
            return try makeDecoder().decode(Response.self, from: Data(json.utf8))
        }
    }

    func send<Response: Decodable & Sendable>(_ endpoint: APIEndpoint, body: (any Encodable & Sendable)?, snakeCase: Bool) async throws -> Response {
        try respond(endpoint, body)
    }

    func send(_ endpoint: APIEndpoint, body: (any Encodable & Sendable)?, snakeCase: Bool) async throws {
        try lock.withLock {
            let call = appendCall(endpoint, body)
            _ = try handler(call)
        }
    }

    func upload<Response: Decodable & Sendable>(_ endpoint: APIEndpoint, field: String, data: Data, filename: String, mimeType: String, fields: [String: String]) async throws -> Response {
        try respond(endpoint, nil)
    }
}

/// Fabrica de JSON con la forma exacta que emite el backend.
enum Fixtures {
    static func card(id: String, name: String = "Bea", photos: Int = 2) -> String {
        let photoList = (0..<photos).map { i in
            #"{"id":"ph-\#(id)-\#(i)","position":\#(i),"state":"approved","url":"http://x/\#(id)/\#(i).jpg","thumb_url":"http://x/\#(id)/t\#(i).jpg"}"#
        }.joined(separator: ",")
        return #"""
        {"user_id":"\#(id)","display_name":"\#(name)","age":29,"bio":"Hola","occupation":null,"city":"Santiago","distance_km":3,
         "gender":"woman","height_cm":null,"kids":null,"smoking":null,"drinking":null,"relationship_goal":"serious","education":null,
         "verified":false,"shared_interest_count":1,
         "interests":[{"id":"i1","slug":"cine","name":"Cine","emoji":"🎬","category":"arts","shared":true}],
         "languages":[],"photos":[\#(photoList)]}
        """#
    }

    static func deck(_ ids: [String], likesLeft: Int? = 50) -> String {
        let left = likesLeft.map(String.init) ?? "null"
        return #"{"context":"dating","cards":[\#(ids.map { card(id: $0) }.joined(separator: ","))],"likes_left_today":\#(left)}"#
    }

    static func likeResponse(match: String? = nil, likesLeft: Int? = 49) -> String {
        #"{"like":{"id":"l1","decision":"like"},"match":\#(match ?? "null"),"likes_left_today":\#(likesLeft.map(String.init) ?? "null")}"#
    }

    static func match(id: String = "m1", other: String = "Bea") -> String {
        #"{"id":"\#(id)","context":"dating","group":null,"other":{"user_id":"u2","display_name":"\#(other)","age":29,"thumb_url":null},"created_at":"2026-09-19T01:00:00.000-03:00","last_message":null,"unread_count":0}"#
    }

    static func message(id: String, body: String, mine: Bool, clientID: String? = nil, at: String = "2026-09-19T01:00:00.000-03:00", readAt: String? = nil) -> String {
        #"{"id":"\#(id)","client_id":\#(clientID.map { "\"\($0)\"" } ?? "null"),"sender_id":"\#(mine ? "me" : "u2")","mine":\#(mine),"kind":"text","body":"\#(body)","image_url":null,"read_at":\#(readAt.map { "\"\($0)\"" } ?? "null"),"created_at":"\#(at)"}"#
    }

    static func serverError(_ code: String, _ message: String = "x") -> APIError { .server(code: code, message: message) }
}

func waitUntil(timeout: Double = 3, _ condition: @escaping @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return await condition()
}
