import XCTest
@testable import Friends

/// La pestaña Chats separa las conversaciones que nacieron en un grupo: no es
/// lo mismo alguien del mazo que alguien con quien compartes un grupo.
@MainActor
final class MatchesListTests: XCTestCase {

    private func model(_ matches: String...) async -> MatchesListViewModel {
        let api = FakeAPI()
        let json = #"{"matches":[\#(matches.joined(separator: ","))]}"#
        api.handler = { call in call.path.hasSuffix("/matches") ? json : nil }
        let vm = MatchesListViewModel(api: api)
        await vm.load()
        return vm
    }

    func testLosDeGrupoVanASuPropiaSeccion() async {
        let vm = await model(
            Self.match(id: "m1", name: "Bea", body: "hola"),
            Self.match(id: "m2", name: "Ana", body: "nos vemos", group: "Runners de Santiago")
        )

        XCTAssertEqual(vm.directConversations.map(\.id), ["m1"])
        XCTAssertEqual(vm.groupConversations.map(\.id), ["m2"])
        XCTAssertEqual(vm.groupConversations.first?.group?.name, "Runners de Santiago")
    }

    func testUnMatchSinMensajesNoEstaEnNingunaDeLasDos() async {
        let vm = await model(Self.match(id: "m1", name: "Bea", body: nil, group: "Fotografía urbana"))

        XCTAssertEqual(vm.newMatches.map(\.id), ["m1"], "sigue siendo un match nuevo")
        XCTAssertTrue(vm.directConversations.isEmpty)
        XCTAssertTrue(vm.groupConversations.isEmpty)
    }

    func testCadaSeccionVaDelMasRecienteAlMasViejo() async {
        let vm = await model(
            Self.match(id: "viejo", name: "Bea", body: "x", at: "2026-09-18T10:00:00.000Z"),
            Self.match(id: "nuevo", name: "Cris", body: "y", at: "2026-09-19T10:00:00.000Z")
        )
        XCTAssertEqual(vm.directConversations.map(\.id), ["nuevo", "viejo"])
    }

    func testSinGruposLaSeccionSeQuedaVacia() async {
        let vm = await model(Self.match(id: "m1", name: "Bea", body: "hola"))
        XCTAssertTrue(vm.groupConversations.isEmpty)
        XCTAssertFalse(vm.directConversations.isEmpty)
    }

    /// La pestana Chats lleva el contador de la barra: la suma tiene que
    /// contar TODOS los matches, tambien los que aun no tienen conversacion.
    func testElContadorSumaLoSinLeerDeTodaLaLista() async {
        let vm = await model(
            Self.match(id: "m1", name: "Bea", body: "hola", unread: 3),
            Self.match(id: "m2", name: "Ana", body: "nos vemos", group: "Runners", unread: 2),
            Self.match(id: "m3", name: "Cris", body: nil, unread: 1)
        )
        XCTAssertEqual(vm.totalUnread, 6)
    }

    func testSinNadaSinLeerElContadorEsCero() async {
        let vm = await model(Self.match(id: "m1", name: "Bea", body: "hola"))
        XCTAssertEqual(vm.totalUnread, 0)
    }

    private static func match(id: String, name: String, body: String?,
                              group: String? = nil,
                              unread: Int = 0,
                              at: String = "2026-09-19T12:00:00.000Z") -> String {
        let last = body.map {
            #"{"id":"msg-\#(id)","client_id":null,"sender_id":"o","mine":false,"kind":"text","body":"\#($0)","image_url":null,"read_at":null,"created_at":"\#(at)"}"#
        } ?? "null"
        let groupJSON = group.map { #"{"id":"g","slug":"g","name":"\#($0)"}"# } ?? "null"
        return #"""
        {"id":"\#(id)","context":"dating","group":\#(groupJSON),
         "other":{"user_id":"u-\#(id)","display_name":"\#(name)","age":30,"thumb_url":null},
         "created_at":"\#(at)","last_message":\#(last),"unread_count":\#(unread)}
        """#
    }
}
