import XCTest

/// Crear un grupo de punta a punta. Ojo: deja un grupo de verdad en la base de
/// desarrollo cada vez que corre. `rake dev:reset` limpia lo sembrado.
@MainActor
final class GroupCreationUITests: XCTestCase {
    func testCrearGrupo() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Groups"].waitForExistence(timeout: 20))
        app.buttons["Groups"].tap()
        Thread.sleep(forTimeInterval: 4)

        XCTAssertTrue(app.buttons["Crear grupo"].waitForExistence(timeout: 8))
        app.buttons["Crear grupo"].tap()
        Thread.sleep(forTimeInterval: 3)

        let nombre = app.textFields["Tu nombre"].exists
            ? app.textFields["Tu nombre"]
            : app.textFields.firstMatch
        XCTAssertTrue(nombre.waitForExistence(timeout: 5), "no encuentro el campo del nombre")
        nombre.tap()
        let titulo = "Grupo UAT \(Int.random(in: 100...999))"
        nombre.typeText(titulo)
        Thread.sleep(forTimeInterval: 1)

        let crear = app.buttons["Crear"]
        XCTAssertTrue(crear.exists, "no hay boton Crear")
        XCTAssertTrue(crear.isEnabled, "el boton Crear esta apagado con el nombre puesto")
        crear.tap()
        Thread.sleep(forTimeInterval: 6)

        XCTAssertFalse(app.buttons["Crear"].exists, "la hoja no se cerro")
        XCTAssertTrue(app.staticTexts[titulo].exists, "el grupo nuevo no aparece")

        // La hoja se cierra, el grupo sale en la lista y se abre su ficha.

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "TrasCrearGrupo"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
