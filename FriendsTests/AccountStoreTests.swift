import XCTest
@testable import Friends

/// El JSON de /me. Funcion de fichero: el closure del `FakeAPI` corre fuera
/// del main actor y no puede capturar el XCTestCase.
private let meJSON = #"""
{"user":{"id":"u-1","handle":"yo","onboarding_completed":true},
 "profile":{"display_name":"Ana"},"photos":[],"interest_ids":[],"languages":[]}
"""#

@MainActor
final class AccountStoreTests: XCTestCase {

    private func api() -> FakeAPI {
        let api = FakeAPI()
        api.handler = { call in call.path.hasSuffix("/me") ? meJSON : nil }
        return api
    }

    /// Al abrir la app, el mazo y la lista de chats piden la cuenta a la vez.
    /// Antes el segundo se iba de vacio en vez de esperar, y de ese `nil` salia
    /// el "No se pudo abrir el chat" con la red perfectamente bien.
    func testDosPeticionesALaVezRecibenLasDosLaCuenta() async {
        let store = AccountStore(api: api())

        async let first = store.refresh()
        async let second = store.refresh()
        let (one, two) = await (first, second)

        XCTAssertEqual(one?.user.id, "u-1")
        XCTAssertEqual(two?.user.id, "u-1", "el segundo en llegar tambien tiene que esperar")
    }

    /// Y se pide UNA sola vez, no una por pantalla.
    func testDosPeticionesALaVezSonUnaSolaLlamada() async {
        let api = api()
        let store = AccountStore(api: api)

        async let first: MeResponse? = store.refresh()
        async let second: MeResponse? = store.refresh()
        _ = await (first, second)

        XCTAssertEqual(api.calls(matching: "/me").count, 1)
    }

    func testRequireUserIDNoVuelveAPedirLaCuentaSiYaLaTiene() async {
        let api = api()
        let store = AccountStore(api: api)

        let first = await store.requireUserID()
        let second = await store.requireUserID()

        XCTAssertEqual(first, "u-1")
        XCTAssertEqual(second, "u-1")
        XCTAssertEqual(api.calls(matching: "/me").count, 1)
    }

    /// Tras una peticion fallida hay que poder volver a intentarlo: la de antes
    /// no se puede quedar pegada.
    func testDespuesDeUnFalloSeVuelveAPedir() async {
        let api = FakeAPI()
        api.handler = { _ in nil }          // 404 en todo
        let store = AccountStore(api: api)

        let first = await store.refresh()
        let second = await store.refresh()
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(api.calls(matching: "/me").count, 2, "el segundo intento tiene que salir de verdad")
    }
}
