import XCTest
@testable import Friends

/// La fecha de nacimiento viaja como "yyyy-MM-dd" gregoriano.
@MainActor
final class BirthdateFormatTests: XCTestCase {

    func testSiempreGregorianoYConCuatroDigitosDeAno() {
        var components = DateComponents()
        components.year = 1994; components.month = 3; components.day = 7
        let date = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertEqual(OnboardingViewModel.isoDay.string(from: date), "1994-03-07")
    }

    /// Con el calendario budista, un `DateFormatter` recien hecho escribe 2537
    /// donde el servidor espera 1994, y el alta se rechaza por menor de edad.
    func testNoLeAfectaElCalendarioDelTelefono() {
        let ingenuo = DateFormatter()
        ingenuo.calendar = Calendar(identifier: .buddhist)
        ingenuo.locale = Locale(identifier: "th_TH")
        ingenuo.dateFormat = "yyyy-MM-dd"

        var components = DateComponents()
        components.year = 1994; components.month = 3; components.day = 7
        let date = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertNotEqual(ingenuo.string(from: date), "1994-03-07", "premisa del test")
        XCTAssertEqual(OnboardingViewModel.isoDay.string(from: date), "1994-03-07")
    }

    func testLeeDeVueltaLoQueEscribe() {
        let text = "2001-12-31"
        let date = OnboardingViewModel.isoDay.date(from: text)
        XCTAssertEqual(date.map(OnboardingViewModel.isoDay.string(from:)), text)
    }
}

@MainActor
final class OnboardingRulesTests: XCTestCase {

    private func model() -> OnboardingViewModel {
        OnboardingViewModel(session: SessionViewModel())
    }

    /// Antes `canAdvance` era `true` para la bio pasara lo que pasara: se
    /// mandaban 600 caracteres y el rechazo llegaba del servidor.
    func testLaBioNoPuedePasarDelLimite() {
        let vm = model()
        vm.bio = String(repeating: "a", count: OnboardingViewModel.maxBio)
        XCTAssertTrue(vm.canAdvance(at: .bio))

        vm.bio = String(repeating: "a", count: OnboardingViewModel.maxBio + 1)
        XCTAssertFalse(vm.canAdvance(at: .bio))
        XCTAssertFalse(vm.missingHint(at: .bio).isEmpty)
    }

    /// El boton "Siguiente" va apagado: lo que falta tiene que poder contarse,
    /// en TODOS los pasos, o la gente se queda mirando un boton gris.
    func testTodoPasoBloqueadoDiceQueLeFalta() {
        let vm = model()
        for step in OnboardingViewModel.Step.allCases where !vm.canAdvance(at: step) {
            XCTAssertFalse(vm.missingHint(at: step).isEmpty, "el paso \(step) no dice que falta")
        }
    }

    func testLosMinimosSonLosQueDiceElTexto() {
        let vm = model()
        XCTAssertFalse(vm.canAdvance(at: .interests))
        vm.selectedInterests = ["a", "b"]
        XCTAssertFalse(vm.canAdvance(at: .interests))
        vm.selectedInterests = ["a", "b", "c"]
        XCTAssertTrue(vm.canAdvance(at: .interests))

        vm.displayName = "A"
        XCTAssertFalse(vm.canAdvance(at: .name))
        vm.displayName = "Ana"
        XCTAssertTrue(vm.canAdvance(at: .name))
    }

    func testMenorDeEdadNoPasaDeLaFechaDeNacimiento() {
        let vm = model()
        vm.birthdate = Calendar.current.date(byAdding: .year, value: -17, to: .now)!
        XCTAssertFalse(vm.canAdvance(at: .birthdate))
        vm.birthdate = Calendar.current.date(byAdding: .year, value: -18, to: .now)!
        XCTAssertTrue(vm.canAdvance(at: .birthdate))
    }
}
