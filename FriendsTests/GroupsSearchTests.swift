import XCTest
@testable import Friends

/// El JSON de un grupo, con los mismos campos que emite el backend.
///
/// Es una funcion de fichero, no un miembro estatico del test: dentro del
/// closure del `FakeAPI`, escribir `Self.algo` captura `self` —y este test esta
/// aislado al main actor—, asi que el handler acabaria ejecutandose fuera de su
/// actor y el proceso de pruebas se cae de golpe, sin fallar ningun assert.
private func groupJSON(_ name: String) -> String {
    #"""
    {"id":"\#(name)","slug":"\#(name.lowercased())","name":"\#(name)","description":null,
     "category":"sports","visibility":"public_group","status":"active","city":null,
     "members_count":1,"cover_url":null,"interests":[],"is_member":true,"role":"owner",
     "distance_km":null,"invite_code":null}
    """#
}

private func groupsJSON(_ names: [String]) -> String {
    #"{"groups":[\#(names.map(groupJSON).joined(separator: ","))]}"#
}

/// Buscar tiene que encontrar tambien TUS grupos. El servidor los excluye del
/// descubrimiento (ya estas dentro), asi que si el filtro no estuviera en el
/// cliente, buscar un grupo recien creado diria "sin resultados" teniendolo
/// delante.
@MainActor
final class GroupsSearchTests: XCTestCase {

    private func model(mine: [String], discover: [String] = []) async -> GroupsViewModel {
        // Las dos respuestas se arman AQUI, no dentro del handler: el closure
        // corre fuera del main actor y no puede tocar nada de este test.
        let mineJSON = groupsJSON(mine)
        let discoverJSON = groupsJSON(discover)
        let api = FakeAPI()
        api.handler = { call in
            guard call.path.hasSuffix("/groups") else { return nil }
            return call.query["scope"] == "mine" ? mineJSON : discoverJSON
        }
        let vm = GroupsViewModel(api: api)
        await vm.load()
        return vm
    }

    func testSinBusquedaSalenTodosLosTuyos() async {
        let vm = await model(mine: ["Crest", "Runners de Santiago"])
        XCTAssertEqual(vm.visibleMine.count, 2)
        XCTAssertFalse(vm.hasNoResults)
    }

    func testBuscarEncuentraUnGrupoTuyo() async {
        let vm = await model(mine: ["Crest", "Runners de Santiago"])
        vm.query = "Crest"
        XCTAssertEqual(vm.visibleMine.map(\.name), ["Crest"])
        XCTAssertFalse(vm.hasNoResults, "estaba delante: no puede decir que no hay nada")
    }

    func testLaBusquedaIgnoraMayusculas() async {
        let vm = await model(mine: ["Crest"])
        vm.query = "crEST"
        XCTAssertEqual(vm.visibleMine.map(\.name), ["Crest"])
    }

    func testBuscarAlgoQueNoExisteSiDaVacio() async {
        let vm = await model(mine: ["Crest"])
        vm.query = "zzzz"
        XCTAssertTrue(vm.visibleMine.isEmpty)
        XCTAssertTrue(vm.hasNoResults)
    }
}
