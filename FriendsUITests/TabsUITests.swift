import XCTest

/// Recorre las pestanas y guarda una captura de cada una. Sirve de humo: si una
/// pantalla revienta al abrirse, la pestana no aparece y el test falla.
final class TabsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testEachTabOpens() {
        let app = XCUIApplication()
        app.launch()

        for tab in ["Date", "Likes", "Groups", "Chats", "Profile"] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 20), "no aparecio la pestana \(tab)")
            button.tap()
            // Da tiempo a que cargue lo que pide a la API.
            Thread.sleep(forTimeInterval: 3)

            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = tab
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }
}
