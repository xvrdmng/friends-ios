import XCTest

/// El chat tiene que abrir, y toda hoja tiene que tener salida. Antes el chat
/// se presentaba vacio si aun no se sabia mi id, y Bloqueados no tenia boton.
final class ChatOpensUITests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    func testElChatAbreYSePuedeVolver() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Chats"].waitForExistence(timeout: 20))
        app.buttons["Chats"].tap()
        Thread.sleep(forTimeInterval: 5)

        // La primera conversacion de la lista, sea cual sea.
        let fila = app.cells.firstMatch
        guard fila.waitForExistence(timeout: 8) else {
            print("### sin matches en la lista: no hay chat que abrir ###")
            return
        }
        fila.tap()
        Thread.sleep(forTimeInterval: 5)

        // Abierto = hay compositor, o al menos el boton de volver. Una pantalla
        // en blanco sin nada que tocar es justo el fallo que perseguimos.
        let compositor = app.textFields["Mensaje"].exists || app.textViews["Mensaje"].exists
        let volver = app.buttons["Volver"].exists
        XCTAssertTrue(compositor || volver, "el chat abrio en blanco, sin compositor ni salida")

        XCTAssertTrue(volver, "el chat no tiene boton de volver")
        if volver { app.buttons["Volver"].tap() }
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.buttons["Chats"].exists, "no volvimos a la lista")
    }

    func testBloqueadosTieneSalida() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 20))
        app.buttons["Profile"].tap()
        Thread.sleep(forTimeInterval: 4)

        let fila = app.buttons["Cuentas bloqueadas"]
        if !fila.exists { app.swipeUp(); Thread.sleep(forTimeInterval: 1) }
        XCTAssertTrue(fila.waitForExistence(timeout: 5))
        fila.tap()
        Thread.sleep(forTimeInterval: 3)

        XCTAssertTrue(app.buttons["Listo"].exists, "Bloqueados sigue sin boton de salida")
        app.buttons["Listo"].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.buttons["Profile"].exists, "no volvimos al perfil")
    }
}
