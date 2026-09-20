import XCTest
@testable import Friends

/// Los avisos ya los mandaba el servidor; lo que se prueba aqui es el trato:
/// que el token se escriba como el servidor lo espera y que el `match_id` del
/// aviso se sepa leer para abrir la conversacion correcta.
final class PushTokenTests: XCTestCase {

    func testElTokenVaEnHexadecimalConDosDigitosPorByte() {
        let data = Data([0x00, 0x0a, 0xff, 0x7f])
        XCTAssertEqual(PushService.hexToken(from: data), "000aff7f")
    }

    func testUnTokenVacioNoInventaNada() {
        XCTAssertEqual(PushService.hexToken(from: Data()), "")
    }

    func testLaLongitudEsElDobleDeLosBytes() {
        let data = Data((0..<32).map { UInt8($0) })
        XCTAssertEqual(PushService.hexToken(from: data).count, 64)
    }
}

final class PushPayloadTests: XCTestCase {

    /// Apnotic mete el `custom_payload` al nivel de arriba del aviso.
    func testLeeElMatchDelNivelDeArriba() {
        let userInfo: [AnyHashable: Any] = ["type": "message", "match_id": "m-42"]
        XCTAssertEqual(PushService.matchID(in: userInfo), "m-42")
    }

    /// Y si algun dia viniera anidado bajo "data", tambien.
    func testLeeElMatchAnidado() {
        let userInfo: [AnyHashable: Any] = ["data": ["type": "match", "match_id": "m-7"]]
        XCTAssertEqual(PushService.matchID(in: userInfo), "m-7")
    }

    func testUnAvisoSinMatchNoLlevaANingunSitio() {
        XCTAssertNil(PushService.matchID(in: [:]))
        XCTAssertNil(PushService.matchID(in: ["aps": ["alert": "hola"]]))
        XCTAssertNil(PushService.matchID(in: ["match_id": 42]), "un id que no es texto no vale")
    }
}

@MainActor
final class PushRegistrationTests: XCTestCase {

    func testDarDeAltaElTokenMandaElEntornoDeEstaBuild() async {
        let api = FakeAPI()
        api.handler = { _ in "" }
        let push = PushService(api: api)

        push.didRegister(deviceToken: Data([0xab, 0xcd]))
        let sent = await waitUntil { !api.calls(matching: "/devices").isEmpty }
        XCTAssertTrue(sent)

        let call = api.calls(matching: "/devices")[0]
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.body["token"] as? String, "abcd")
        XCTAssertEqual(call.body["environment"] as? String, PushService.environment)
    }

    /// Un token del sandbox no vale en produccion: la build de desarrollo tiene
    /// que decirlo o los avisos se pierden sin ruido.
    func testLaBuildDeDesarrolloSeRegistraEnElSandbox() {
        #if DEBUG
        XCTAssertEqual(PushService.environment, "development")
        #else
        XCTAssertEqual(PushService.environment, "production")
        #endif
    }

    /// Al cerrar sesion, los avisos de esa cuenta no pueden seguir llegando.
    func testCerrarSesionDaDeBajaElTokenPorSuValor() async {
        let api = FakeAPI()
        api.handler = { _ in "" }
        let push = PushService(api: api)

        push.didRegister(deviceToken: Data([0x01, 0x02]))
        _ = await waitUntil { !api.calls(matching: "/devices").isEmpty }
        await push.unregister()

        let delete = api.calls.first { $0.method == "DELETE" }
        XCTAssertEqual(delete?.path, "/api/v1/devices/0102")
        XCTAssertNil(push.deviceToken)
    }

    func testSinTokenNoHayNadaQueDarDeBaja() async {
        let api = FakeAPI()
        api.handler = { _ in "" }
        let push = PushService(api: api)
        await push.unregister()
        XCTAssertTrue(api.calls(matching: "/devices").isEmpty)
    }
}
