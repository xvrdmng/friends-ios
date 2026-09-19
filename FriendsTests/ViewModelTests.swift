import XCTest
@testable import Friends

@MainActor
final class DeckViewModelTests: XCTestCase {
    private var api: FakeAPI!

    override func setUp() async throws { api = FakeAPI() }

    private func model(_ context: DeckContext = .dating, groupSlug: String? = nil, groupID: String? = nil) -> DeckViewModel {
        DeckViewModel(context: context, groupSlug: groupSlug, groupID: groupID, api: api)
    }

    private func serve(deck ids: [String], likes: @escaping (FakeAPI.Call) throws -> String? = { _ in Fixtures.likeResponse() }) {
        api.handler = { call in
            if call.path.hasSuffix("/deck") { return Fixtures.deck(ids) }
            if call.path.hasSuffix("/likes") { return try likes(call) }
            return nil
        }
    }

    func testCargaElMazoYPasaAReady() async {
        serve(deck: ["a", "b", "c"])
        let vm = model()
        await vm.load()
        XCTAssertEqual(vm.cards.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(vm.phase, .ready)
        XCTAssertEqual(vm.likesLeft, 50)
        XCTAssertEqual(api.calls.first?.query["context"], "dating")
    }

    func testMazoVacioEsEmpty() async {
        serve(deck: [])
        let vm = model(); await vm.load()
        XCTAssertEqual(vm.phase, .empty)
    }

    func testDecidirQuitaLaCartaAlInstanteYEnviaElLike() async {
        serve(deck: ["a", "b"])
        let vm = model(); await vm.load()
        vm.decide(.like)

        XCTAssertEqual(vm.cards.map(\.id), ["b"], "la carta sale antes de que responda el servidor")
        let sent = await waitUntil { !self.api.calls(matching: "/likes").isEmpty }
        XCTAssertTrue(sent)
        let body = api.calls(matching: "/likes")[0].body
        XCTAssertEqual(body["to_user_id"] as? String, "a")
        XCTAssertEqual(body["context"] as? String, "dating")
        XCTAssertEqual(body["decision"] as? String, "like")
    }

    func testUltimaCartaDejaElMazoVacio() async {
        serve(deck: ["a"])
        let vm = model(); await vm.load()
        vm.decide(.pass)
        XCTAssertEqual(vm.phase, .empty)
    }

    func testMatchDelServidorSeExponeParaLaCelebracion() async {
        serve(deck: ["a", "b"], likes: { _ in Fixtures.likeResponse(match: Fixtures.match(other: "Bea")) })
        let vm = model(); await vm.load()
        vm.decide(.like)
        let matched = await waitUntil { vm.newMatch != nil }
        XCTAssertTrue(matched)
        XCTAssertEqual(vm.newMatch?.other.displayName, "Bea")
        vm.dismissMatch()
        XCTAssertNil(vm.newMatch)
    }

    func testLimiteDiarioDevuelveLaCartaYAbreElPaywall() async {
        serve(deck: ["a", "b"], likes: { _ in throw Fixtures.serverError("like_limit_reached") })
        let vm = model(); await vm.load()
        vm.decide(.like)

        let reopened = await waitUntil { vm.showPaywall }
        XCTAssertTrue(reopened)
        XCTAssertEqual(vm.cards.first?.id, "a", "la carta que no se pudo enviar vuelve arriba")
        XCTAssertEqual(vm.phase, .ready)
    }

    func testRechazoDefinitivoDescartaLaCartaSinPaywall() async {
        serve(deck: ["a", "b"], likes: { _ in throw Fixtures.serverError("not_found") })
        let vm = model(); await vm.load()
        vm.decide(.like)
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(vm.cards.map(\.id), ["b"], "alguien bloqueado o borrado no debe volver")
        XCTAssertFalse(vm.showPaywall)
    }

    func testRedCaidaReintentaYLuegoDevuelveLaCartaConAviso() async {
        var attempts = 0
        serve(deck: ["a", "b"], likes: { _ in attempts += 1; throw APIError.offline })
        let vm = model(); await vm.load()
        vm.decide(.like)

        let back = await waitUntil(timeout: 8) { vm.cards.first?.id == "a" }
        XCTAssertTrue(back, "tras reintentar, la decision no se pierde")
        XCTAssertEqual(attempts, 3)
        XCTAssertNotNil(vm.toast)
    }

    func testNoSePideElMazoDosVecesALaVez() async {
        serve(deck: ["a", "b", "c"])
        let vm = model()
        async let first: () = vm.load()
        async let second: () = vm.load()
        _ = await (first, second)
        XCTAssertEqual(api.calls(matching: "/deck").count, 1)
    }

    func testRecargaCuandoQuedanPocasSinRepetirCartas() async {
        var served = 0
        api.handler = { call in
            if call.path.hasSuffix("/deck") { served += 1; return served == 1 ? Fixtures.deck(["a", "b", "c", "d", "e", "f"]) : Fixtures.deck(["e", "f", "g", "h"]) }
            return Fixtures.likeResponse()
        }
        let vm = model(); await vm.load()
        vm.decide(.pass)   // quedan 5 = umbral -> recarga
        let refilled = await waitUntil { vm.cards.count >= 7 }
        XCTAssertTrue(refilled)
        XCTAssertEqual(vm.cards.map(\.id), ["b", "c", "d", "e", "f", "g", "h"], "e y f ya estaban: no se duplican")
    }

    func testRequisitosDelServidorSeTraducenAPantallasDeAyuda() async {
        let cases: [(String, DeckViewModel.Requirement)] = [
            ("location_required", .location), ("mode_disabled", .mode),
            ("language_profile_required", .languages), ("profile_incomplete", .completeProfile)
        ]
        for (code, expected) in cases {
            api.handler = { _ in throw Fixtures.serverError(code) }
            let vm = model(); await vm.load()
            XCTAssertEqual(vm.phase, .needs(expected), code)
        }
    }

    func testFalloDeRedSinCartasEsFailedYConCartasSeMantieneReady() async {
        api.handler = { _ in throw APIError.offline }
        let vm = model(); await vm.load()
        if case .failed = vm.phase {} else { XCTFail("sin cartas y sin red debe ser failed") }

        api.handler = { _ in Fixtures.deck(["a"]) }
        await vm.load(reset: true)
        api.handler = { _ in throw APIError.offline }
        await vm.load()
        XCTAssertEqual(vm.phase, .ready, "una recarga fallida no debe tirar el mazo que ya hay")
    }

    func testDeshacerVuelveLaUltimaCartaYSuLikeSeBorra() async {
        api.handler = { call in
            if call.path.hasSuffix("/deck") { return Fixtures.deck(["a", "b"]) }
            if call.path.hasSuffix("/rewind") { return "{}" }
            return Fixtures.likeResponse()
        }
        let vm = model(); await vm.load()
        vm.decide(.like)
        XCTAssertTrue(vm.canRewind)
        await vm.rewind()
        XCTAssertEqual(vm.cards.map(\.id), ["a", "b"])
        XCTAssertFalse(vm.canRewind)
        XCTAssertEqual(api.calls(matching: "/rewind").count, 1)
    }

    func testDeshacerSinPremiumAbreElPaywallYNoMuevePila() async {
        api.handler = { call in
            if call.path.hasSuffix("/deck") { return Fixtures.deck(["a", "b"]) }
            if call.path.hasSuffix("/rewind") { throw Fixtures.serverError("premium_required") }
            return Fixtures.likeResponse()
        }
        let vm = model(); await vm.load()
        vm.decide(.pass)
        await vm.rewind()
        XCTAssertTrue(vm.showPaywall)
        XCTAssertEqual(vm.cards.map(\.id), ["b"])
    }

    func testMazoDeGrupoEnviaElGrupoEnCadaLike() async {
        serve(deck: ["a"])
        let vm = model(.group, groupSlug: "runners", groupID: "g-1"); await vm.load()
        vm.decide(.like)
        _ = await waitUntil { !self.api.calls(matching: "/likes").isEmpty }
        XCTAssertEqual(api.calls(matching: "/likes")[0].body["group_id"] as? String, "g-1")
        XCTAssertEqual(api.calls(matching: "/likes")[0].body["context"] as? String, "group")
        XCTAssertEqual(api.calls(matching: "/deck")[0].path, "/api/v1/groups/runners/deck")
    }

    func testQuitarAUnBloqueadoLoSacaDelMazo() async {
        serve(deck: ["a", "b"])
        let vm = model(); await vm.load()
        vm.remove(userID: "a")
        XCTAssertEqual(vm.cards.map(\.id), ["b"])
        vm.remove(userID: "b")
        XCTAssertEqual(vm.phase, .empty)
    }

    func testSuperlikeViajaComoSuperlike() async {
        serve(deck: ["a", "b"])
        let vm = model(); await vm.load()
        vm.decide(.superlike)
        _ = await waitUntil { !self.api.calls(matching: "/likes").isEmpty }
        XCTAssertEqual(api.calls(matching: "/likes")[0].body["decision"] as? String, "superlike")
    }
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var api: FakeAPI!
    private let match: Match = try! {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; d.dateDecodingStrategy = .iso8601
        return try d.decode(Match.self, from: Data(Fixtures.match().utf8))
    }()

    override func setUp() async throws { api = FakeAPI() }

    /// Sin token en el Keychain de los tests el cable no llega a abrir el socket.
    private func model() -> ChatViewModel {
        ChatViewModel(match: match, myID: "me", api: api, cable: CableClient(baseURL: URL(string: "http://localhost:1")!))
    }

    private func page(_ messages: [String], hasMore: Bool = false) -> String {
        #"{"messages":[\#(messages.joined(separator: ","))],"has_more":\#(hasMore)}"#
    }

    func testCargaLosMensajesEnOrdenCronologico() async {
        api.handler = { call in
            call.path.hasSuffix("/messages") && call.method == "GET"
                ? self.page([Fixtures.message(id: "m2", body: "segundo", mine: false, at: "2026-09-19T01:02:00Z"),
                             Fixtures.message(id: "m1", body: "primero", mine: true, at: "2026-09-19T01:01:00Z")])
                : "{}"
        }
        let vm = model(); await vm.start()
        XCTAssertEqual(vm.messages.map(\.body), ["primero", "segundo"], "el servidor manda del mas nuevo al mas viejo")
        XCTAssertFalse(vm.isLoading)
        vm.stop()
    }

    func testEnviarApareceAlInstanteYSeReconciliaConLaRespuesta() async {
        api.handler = { call in
            if call.method == "POST" && call.path.hasSuffix("/messages") {
                let clientID = call.body["client_id"] as? String ?? ""
                return #"{"message":\#(Fixtures.message(id: "srv-1", body: "hola", mine: true, clientID: clientID))}"#
            }
            return self.page([])
        }
        let vm = model(); await vm.start()
        vm.draft = "hola"; vm.send()

        XCTAssertEqual(vm.messages.count, 1); XCTAssertTrue(vm.messages[0].id.hasPrefix("local-"))
        XCTAssertEqual(vm.draft, "", "el campo se vacia al enviar")
        let confirmed = await waitUntil { vm.messages.first?.id == "srv-1" }
        XCTAssertTrue(confirmed)
        XCTAssertEqual(vm.messages.count, 1, "el mensaje local se REEMPLAZA, no se duplica")
        XCTAssertTrue(vm.sendStates.isEmpty)
        vm.stop()
    }

    func testFalloDeRedMarcaFailedYReintentarUsaElMismoClientID() async {
        var failing = true
        api.handler = { call in
            guard call.method == "POST" else { return self.page([]) }
            if failing { throw APIError.offline }
            let clientID = call.body["client_id"] as? String ?? ""
            return #"{"message":\#(Fixtures.message(id: "srv-1", body: "hola", mine: true, clientID: clientID))}"#
        }
        let vm = model(); await vm.start()
        vm.draft = "hola"; vm.send()
        let failed = await waitUntil { vm.sendStates.values.contains(.failed) }
        XCTAssertTrue(failed)

        failing = false
        vm.retry(vm.messages[0])
        let sent = await waitUntil { vm.messages.first?.id == "srv-1" }
        XCTAssertTrue(sent)

        let ids = api.calls.filter { $0.method == "POST" }.compactMap { $0.body["client_id"] as? String }
        XCTAssertEqual(ids.count, 2); XCTAssertEqual(Set(ids).count, 1, "el reintento usa el MISMO client_id: el servidor no lo duplica")
        vm.stop()
    }

    func testMensajesVaciosONoSeEnvian() async {
        api.handler = { _ in self.page([]) }
        let vm = model(); await vm.start()
        vm.draft = "   \n "; vm.send()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertTrue(api.calls.filter { $0.method == "POST" }.isEmpty)
        vm.stop()
    }

    func testPaginaHaciaAtrasConElIdDelMensajeMasAntiguo() async {
        api.handler = { call in
            if call.query["before"] == "m2" { return self.page([Fixtures.message(id: "m1", body: "viejo", mine: false, at: "2026-09-19T01:00:00Z")]) }
            return self.page([Fixtures.message(id: "m3", body: "nuevo", mine: true, at: "2026-09-19T01:02:00Z"),
                              Fixtures.message(id: "m2", body: "medio", mine: false, at: "2026-09-19T01:01:00Z")], hasMore: true)
        }
        let vm = model(); await vm.start()
        XCTAssertTrue(vm.hasMore)
        await vm.loadOlder()
        XCTAssertEqual(vm.messages.map(\.id), ["m1", "m2", "m3"])
        XCTAssertFalse(vm.hasMore)
        vm.stop()
    }

    func testUnRefrescoNoPisaElIndicadorDePaginasAnteriores() async {
        var latest = self.page([Fixtures.message(id: "m2", body: "b", mine: false)], hasMore: true)
        api.handler = { _ in latest }
        let vm = model(); await vm.start()
        XCTAssertTrue(vm.hasMore)
        latest = self.page([Fixtures.message(id: "m2", body: "b", mine: false)], hasMore: false)
        await vm.refresh()
        XCTAssertTrue(vm.hasMore, "ya cargamos la primera pagina: un refresco no decide si hay mas atras")
        vm.stop()
    }

    func testMatchDeshechoMarcaLaConversacionComoCerrada() async {
        api.handler = { _ in throw Fixtures.serverError("not_found") }
        let vm = model(); await vm.start()
        XCTAssertTrue(vm.isClosed)
        vm.stop()
    }

    func testMarcarLeidoSoloSiHayMensajesAjenosSinLeer() async {
        api.handler = { call in
            call.method == "GET" ? self.page([Fixtures.message(id: "m1", body: "hola", mine: false)]) : "{}"
        }
        let vm = model(); await vm.start()
        XCTAssertEqual(api.calls(matching: "/read").count, 1)
        XCTAssertNotNil(vm.messages[0].readAt)
        await vm.markRead()
        XCTAssertEqual(api.calls(matching: "/read").count, 1, "no repite si no hay nada por leer")
        vm.stop()
    }

    func testAlDeshacerElMatchLlamaAlServidor() async {
        api.handler = { _ in self.page([]) }
        let vm = model(); await vm.start()
        let done = await vm.unmatch()
        XCTAssertTrue(done)
        XCTAssertEqual(api.calls.last?.method, "DELETE")
        vm.stop()
    }
}
