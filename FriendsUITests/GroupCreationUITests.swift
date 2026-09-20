import XCTest

/// Crear un grupo de punta a punta. Ojo: deja un grupo de verdad en la base de
/// desarrollo cada vez que corre. `rake dev:reset` limpia lo sembrado.
@MainActor
final class GroupCreationUITests: XCTestCase {

    /// El camino corto: solo el nombre.
    func testCrearGrupoSoloConNombre() {
        let app = XCUIApplication()
        abrirFormulario(app)

        let titulo = escribirNombre(app)
        pulsarCrear(app)

        XCTAssertFalse(app.buttons["Crear"].exists, "la hoja no se cerro")
        XCTAssertTrue(app.staticTexts[titulo].exists, "el grupo nuevo no aparece")
    }

    /// El camino que hace de verdad una persona: categoria, intereses, privado.
    func testCrearGrupoRellenandoTodo() {
        let app = XCUIApplication()
        abrirFormulario(app)

        let titulo = escribirNombre(app)

        // Descripcion
        let desc = app.textViews.firstMatch
        if desc.exists { desc.tap(); desc.typeText("Grupo de prueba del UAT") }

        // Categoria: una que no sea la de por defecto.
        for etiqueta in ["Música", "Comida", "Arte"] where app.buttons[etiqueta].exists {
            app.buttons[etiqueta].tap()
            Thread.sleep(forTimeInterval: 1)
            break
        }

        // Un par de intereses de esa categoria, si aparecen.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        print("### BOTONES DEL FORMULARIO ###")
        for b in app.buttons.allElementsBoundByIndex.prefix(40) { print("·", b.label) }
        print("### FIN ###")

        // Privado
        if app.switches["Grupo privado"].exists {
            app.switches["Grupo privado"].tap()
            Thread.sleep(forTimeInterval: 1)
        }

        pulsarCrear(app)

        for a in app.alerts.allElementsBoundByIndex { print("### ALERTA:", a.label, "###") }
        XCTAssertFalse(app.buttons["Crear"].exists, "la hoja no se cerro: la creacion fallo")
        XCTAssertTrue(app.staticTexts[titulo].exists, "el grupo nuevo no aparece en la lista")
    }

    // MARK: - Pasos

    private func abrirFormulario(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["Groups"].waitForExistence(timeout: 20))
        app.buttons["Groups"].tap()
        Thread.sleep(forTimeInterval: 4)
        XCTAssertTrue(app.buttons["Crear grupo"].waitForExistence(timeout: 8))
        app.buttons["Crear grupo"].tap()
        Thread.sleep(forTimeInterval: 3)
    }

    private func escribirNombre(_ app: XCUIApplication) -> String {
        let campo = app.textFields["Tu nombre"].exists ? app.textFields["Tu nombre"] : app.textFields.firstMatch
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "no encuentro el campo del nombre")
        campo.tap()
        let titulo = "Grupo UAT \(Int.random(in: 100...999))"
        campo.typeText(titulo)
        Thread.sleep(forTimeInterval: 1)
        return titulo
    }

    private func pulsarCrear(_ app: XCUIApplication) {
        let crear = app.buttons["Crear"]
        XCTAssertTrue(crear.exists, "no hay boton Crear")
        XCTAssertTrue(crear.isEnabled, "el boton Crear esta apagado")
        crear.tap()
        Thread.sleep(forTimeInterval: 6)
    }
}
