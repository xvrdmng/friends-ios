import XCTest
@testable import Friends

final class Base64URLTests: XCTestCase {
    func testRoundTripSinRelleno() {
        let data = Data([0xfb, 0xff, 0xfe, 0x00, 0x10])
        let encoded = Base64URL.encode(data)
        XCTAssertFalse(encoded.contains("="))
        XCTAssertFalse(encoded.contains("+")); XCTAssertFalse(encoded.contains("/"))
        XCTAssertEqual(Base64URL.decode(encoded), data)
    }

    func testDecodificaValoresConocidos() {
        XCTAssertEqual(Base64URL.decode("aGVsbG8"), Data("hello".utf8))
        XCTAssertEqual(Base64URL.decode("-_8"), Data([0xfb, 0xff]))
        XCTAssertNil(Base64URL.decode("@@@"))
    }
}

final class SwipeMathTests: XCTestCase {
    func testDerechaLargaEsLike() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: 150, height: 5), predicted: .zero), .like)
    }
    func testIzquierdaLargaEsPass() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: -150, height: 0), predicted: .zero), .pass)
    }
    func testArribaEsSuperlike() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: 10, height: -200), predicted: .zero), .superlike)
    }
    func testDiagonalDominadaPorLoHorizontalNoEsSuperlike() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: 200, height: -150), predicted: .zero), .like)
    }
    func testRecorridoCortoNoDecide() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: 60, height: 0), predicted: CGSize(width: 90, height: 0)), .none)
    }
    func testFlickRapidoCuentaAunqueElDedoRecorraPoco() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: 60, height: 0), predicted: CGSize(width: 400, height: 0)), .like)
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: -60, height: 0), predicted: CGSize(width: -400, height: 0)), .pass)
    }
    func testUnFlickCasiInmovilNoCuenta() {
        XCTAssertEqual(SwipeMath.outcome(translation: CGSize(width: 10, height: 0), predicted: CGSize(width: 500, height: 0)), .none)
    }
    func testGiroAcotadoAMasMenos12Grados() {
        XCTAssertEqual(SwipeMath.rotation(forWidth: 10_000), 12)
        XCTAssertEqual(SwipeMath.rotation(forWidth: -10_000), -12)
        XCTAssertEqual(SwipeMath.rotation(forWidth: 0), 0)
    }
    func testSelloCrecienteYAcotado() {
        XCTAssertEqual(SwipeMath.stampOpacity(forWidth: 0, positive: true), 0)
        XCTAssertEqual(SwipeMath.stampOpacity(forWidth: 60, positive: true), 0.5, accuracy: 0.01)
        XCTAssertEqual(SwipeMath.stampOpacity(forWidth: 500, positive: true), 1)
        XCTAssertEqual(SwipeMath.stampOpacity(forWidth: -500, positive: false), 1)
        XCTAssertEqual(SwipeMath.stampOpacity(forWidth: -60, positive: true), 0, "arrastrar a la izquierda no enciende LIKE")
    }
}

final class CableProtocolTests: XCTestCase {
    func testIdentificadorEsJSONEstableDentroDeUnString() {
        let id = CableFrame.identifier(matchID: "abc")
        XCTAssertEqual(id, #"{"channel":"ConversationChannel","match_id":"abc"}"#)
    }

    func testParseaLosFramesDelProtocolo() {
        XCTAssertEqual(CableFrame.parse(#"{"type":"welcome"}"#), .welcome)
        XCTAssertEqual(CableFrame.parse(#"{"type":"ping","message":1758300000}"#), .ping)
        XCTAssertEqual(CableFrame.parse(#"{"type":"confirm_subscription","identifier":"X"}"#), .confirmSubscription(identifier: "X"))
        XCTAssertEqual(CableFrame.parse(#"{"type":"reject_subscription","identifier":"X"}"#), .rejectSubscription(identifier: "X"))
        XCTAssertEqual(CableFrame.parse(#"{"type":"disconnect","reason":"unauthorized","reconnect":false}"#), .disconnect(reason: "unauthorized", reconnect: false))
        XCTAssertEqual(CableFrame.parse("no es json"), .unknown)
    }

    func testDisconnectSinReconnectVaAReconectarPorDefecto() {
        XCTAssertEqual(CableFrame.parse(#"{"type":"disconnect"}"#), .disconnect(reason: nil, reconnect: true))
    }

    func testFrameDeDatosLlevaElPayload() {
        let text = #"{"identifier":"X","message":{"type":"typing","user_id":"u2"}}"#
        guard case .data(let identifier, let payload) = CableFrame.parse(text) else { return XCTFail("deberia ser data") }
        XCTAssertEqual(identifier, "X")
        XCTAssertEqual(CableEventDecoder.decode(payload), .typing(userId: "u2"))
    }

    func testDecodificaMensajeYLeido() {
        let message = Fixtures.message(id: "m1", body: "hola", mine: false, clientID: "c1")
        let payload = Data(#"{"type":"message","message":\#(message)}"#.utf8)
        guard case .message(let decoded)? = CableEventDecoder.decode(payload) else { return XCTFail("deberia ser message") }
        XCTAssertEqual(decoded.body, "hola"); XCTAssertEqual(decoded.clientId, "c1"); XCTAssertFalse(decoded.mine)

        let read = Data(#"{"type":"read","reader_id":"u2","message_ids":["a","b"],"read_at":"2026-09-19T01:00:00Z"}"#.utf8)
        XCTAssertEqual(CableEventDecoder.decode(read), .read(messageIds: ["a", "b"], readerId: "u2"))
    }

    func testIgnoraEventosDesconocidosOMalformados() {
        XCTAssertNil(CableEventDecoder.decode(Data(#"{"type":"algo_nuevo"}"#.utf8)))
        XCTAssertNil(CableEventDecoder.decode(Data("basura".utf8)))
        XCTAssertNil(CableEventDecoder.decode(Data(#"{"type":"message"}"#.utf8)))
    }

    func testComandoDeSuscripcion() throws {
        let text = CableFrame.subscribeCommand(identifier: CableFrame.identifier(matchID: "m1"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String])
        XCTAssertEqual(object["command"], "subscribe")
        XCTAssertEqual(object["identifier"], CableFrame.identifier(matchID: "m1"))
    }
}

final class ModelDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; d.dateDecodingStrategy = .iso8601; return d
    }()

    func testCartaConCamposNulos() throws {
        let card = try decoder.decode(DeckCard.self, from: Data(Fixtures.card(id: "u9", name: "Ana").utf8))
        XCTAssertEqual(card.displayName, "Ana"); XCTAssertNil(card.occupation); XCTAssertEqual(card.distanceKm, 3)
        XCTAssertEqual(card.photos.count, 2); XCTAssertTrue(card.interests[0].shared)
        XCTAssertEqual(card.photos[0].imageURL?.absoluteString, "http://x/u9/0.jpg")
    }

    func testCartaNoExponeCoordenadasNiNacimiento() {
        let keys = Set(Mirror(reflecting: try! decoder.decode(DeckCard.self, from: Data(Fixtures.card(id: "u9").utf8))).children.compactMap(\.label))
        XCTAssertTrue(keys.isDisjoint(with: ["lat", "lng", "latitude", "longitude", "birthdate"]))
    }

    func testMatchConFechaConFraccionesYZonaHoraria() throws {
        let match = try decoder.decode(Match.self, from: Data(Fixtures.match().utf8))
        XCTAssertEqual(match.other.displayName, "Bea"); XCTAssertNil(match.lastMessage)
    }

    func testMensajeConRecibo() throws {
        let json = Fixtures.message(id: "m", body: "x", mine: true, readAt: "2026-09-19T01:02:03.500-03:00")
        XCTAssertNotNil(try decoder.decode(ChatMessage.self, from: Data(json.utf8)).readAt)
    }

    func testMeResponseAceptaLosCamposNuevosYLosViejos() throws {
        let minimal = #"{"user":{"id":"u","handle":"h","onboarding_completed":false},"profile":null}"#
        let me = try decoder.decode(MeResponse.self, from: Data(minimal.utf8))
        XCTAssertNil(me.profile); XCTAssertNil(me.user.premium)

        let full = #"{"user":{"id":"u","handle":"h","onboarding_completed":true,"premium":true,"premium_until":"2026-12-01T00:00:00.000Z","likes_left_today":null},"profile":{"display_name":"Ana","age":30,"city":"Santiago"},"photos":[{"id":"p","url":"http://x/p","thumb_url":"http://x/t","position":0,"state":"pending"}],"interest_ids":["i"],"languages":[]}"#
        let complete = try decoder.decode(MeResponse.self, from: Data(full.utf8))
        XCTAssertEqual(complete.user.premium, true); XCTAssertEqual(complete.profile?.age, 30)
        XCTAssertEqual(complete.photos?.first?.isApproved, false)
    }

    func testCodigosDeErrorDelServidor() throws {
        let payload = try decoder.decode(APIErrorPayload.self, from: Data(#"{"error":{"code":"like_limit_reached","message":"limite"}}"#.utf8))
        XCTAssertEqual(payload.error.code, "like_limit_reached")
        XCTAssertTrue(APIError.server(code: "like_limit_reached", message: "").isLikeLimit)
        XCTAssertFalse(APIError.server(code: "otra", message: "").isLikeLimit)
    }
}

final class EndpointTests: XCTestCase {
    func testRutasYMetodos() {
        XCTAssertEqual(APIEndpoint.like.path, "/api/v1/likes"); XCTAssertEqual(APIEndpoint.like.method, .post)
        XCTAssertEqual(APIEndpoint.photo(id: "p").method, .delete)
        XCTAssertEqual(APIEndpoint.location.method, .put)
        XCTAssertEqual(APIEndpoint.unblock(userID: "u").path, "/api/v1/blocks/u")
        XCTAssertEqual(APIEndpoint.kick(slug: "g", userID: "u").path, "/api/v1/groups/g/members/u")
    }

    func testMazoDeGrupoUsaLaRutaDelGrupoSinContext() {
        let group = APIEndpoint.deck(context: .group, groupSlug: "runners")
        XCTAssertEqual(group.path, "/api/v1/groups/runners/deck"); XCTAssertTrue(group.queryItems.isEmpty)
        let dating = APIEndpoint.deck(context: .dating, groupSlug: nil)
        XCTAssertEqual(dating.path, "/api/v1/deck"); XCTAssertEqual(dating.queryItems.first?.value, "dating")
    }

    func testCursorDeMensajes() {
        XCTAssertEqual(APIEndpoint.messages(matchID: "m", before: "abc").queryItems.first?.value, "abc")
        XCTAssertTrue(APIEndpoint.messages(matchID: "m", before: nil).queryItems.isEmpty)
    }

    func testBusquedaDeGruposIgnoraTextoVacio() {
        let items = APIEndpoint.groups(scope: .discover, category: nil, query: "").queryItems.map(\.name)
        XCTAssertEqual(items, ["scope"])
        let filtered = APIEndpoint.groups(scope: .mine, category: "arts", query: "foto").queryItems.map(\.name)
        XCTAssertEqual(Set(filtered), ["scope", "category", "q"])
    }
}
