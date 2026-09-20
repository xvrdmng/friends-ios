import XCTest

/// Comprueba que las pantallas que se abren desde el perfil responden. Antes
/// habia ocho `.sheet` apilados en la misma vista y casi todos quedaban mudos.
final class PresentationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    func testElPerfilAbreSusPantallas() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 20))
        app.buttons["Profile"].tap()
        Thread.sleep(forTimeInterval: 4)

        // Cada fila abre algo y se cierra; si una no abre, el marcador no aparece.
        let casos: [(fila: String, marcador: String)] = [
            ("Ver cómo te ven", "Listo"),
            ("Filtros de búsqueda", "Distancia máxima"),
            ("Tus idiomas", "Guardar"),
            ("Cuentas bloqueadas", "Bloqueados")
        ]

        for caso in casos {
            let fila = app.buttons[caso.fila]
            if !fila.exists { app.swipeUp() ; Thread.sleep(forTimeInterval: 1) }
            XCTAssertTrue(fila.waitForExistence(timeout: 5), "no encuentro la fila \(caso.fila)")
            fila.tap()
            Thread.sleep(forTimeInterval: 3)

            let abierto = app.staticTexts[caso.marcador].exists
                || app.buttons[caso.marcador].exists
                || app.navigationBars[caso.marcador].exists
            XCTAssertTrue(abierto, "\(caso.fila) no abrio nada")

            for cierre in ["Listo", "Cerrar", "Cancelar"] where app.buttons[cierre].exists {
                app.buttons[cierre].tap(); break
            }
            Thread.sleep(forTimeInterval: 2)
            if !app.buttons["Profile"].exists { app.swipeDown() }
        }
    }

    func testCerrarSesionPideConfirmacion() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 20))
        app.buttons["Profile"].tap()
        Thread.sleep(forTimeInterval: 4)

        let fila = app.buttons["Cerrar sesión"]
        if !fila.exists { app.swipeUp(); Thread.sleep(forTimeInterval: 1) }
        if !fila.exists { app.swipeUp(); Thread.sleep(forTimeInterval: 1) }
        XCTAssertTrue(fila.waitForExistence(timeout: 5), "no encuentro Cerrar sesión")
        fila.tap()
        Thread.sleep(forTimeInterval: 2)

        // El dialogo tiene que salir: antes habia dos y se anulaban entre si.
        XCTAssertTrue(app.staticTexts["¿Cerrar sesión?"].exists
                        || app.buttons["Cancelar"].exists,
                      "no salio el dialogo de cerrar sesión")
        if app.buttons["Cancelar"].exists { app.buttons["Cancelar"].tap() }
    }
}
