import XCTest
@testable import Friends

@MainActor
final class DeckModelsTests: XCTestCase {

    /// Cada contexto tiene UN modelo, y es siempre el mismo. Antes se guardaba
    /// con un salto asincrono, asi que hasta que llegaba, cada redibujo creaba
    /// uno nuevo: la carga iba a un modelo y la pantalla miraba otro.
    func testElMismoContextoDevuelveSiempreElMismoModelo() {
        let models = DeckModels()
        let first = models.model(for: .friendship, groupSlug: nil, groupID: nil)
        let second = models.model(for: .friendship, groupSlug: nil, groupID: nil)
        XCTAssertTrue(first === second)
    }

    func testCadaContextoTieneElSuyo() {
        let models = DeckModels()
        let friendship = models.model(for: .friendship, groupSlug: nil, groupID: nil)
        let language = models.model(for: .language, groupSlug: nil, groupID: nil)
        XCTAssertFalse(friendship === language)
        XCTAssertEqual(friendship.context, .friendship)
        XCTAssertEqual(language.context, .language)
    }

    func testElMazoDeUnGrupoConservaSuSlug() {
        let models = DeckModels()
        let group = models.model(for: .group, groupSlug: "runners", groupID: "g1")
        XCTAssertEqual(group.groupSlug, "runners")
        XCTAssertEqual(group.groupID, "g1")
    }
}
