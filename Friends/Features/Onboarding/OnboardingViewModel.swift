import Foundation
import UIKit

/// Estado del wizard. Cada paso persiste en el servidor al avanzar, asi que
/// cerrar la app no pierde el progreso.
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case name, birthdate, gender, datingPreference, modes, languages, interests, aboutYou, photos, bio

        var title: String {
            switch self {
            case .name:             "¿Como te llamas?"
            case .birthdate:        "¿Cuando naciste?"
            case .gender:           "¿Cual es tu genero?"
            case .datingPreference: "¿Quien te interesa?"
            case .modes:            "¿A que vienes?"
            case .languages:        "Tus idiomas"
            case .interests:        "¿Que te gusta hacer?"
            case .aboutYou:         "Sobre ti"
            case .photos:           "Tus fotos"
            case .bio:              "Cuentate"
            }
        }

        var subtitle: String? {
            switch self {
            case .birthdate:        "Tienes que ser mayor de 18. No se puede cambiar despues."
            case .datingPreference: "Solo afecta al mazo de citas."
            case .modes:            "Puedes elegir mas de uno."
            case .languages:        "Necesitas al menos uno nativo."
            case .photos:           "Sube al menos 2. Hasta 6."
            case .interests:        "Elige al menos 3."
            case .bio:              "Maximo 500 caracteres."
            default:                nil
            }
        }
    }

    // Estado del formulario
    var displayName = ""
    var birthdate = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    var gender: String?
    var datingPreference: String?
    var modeDating = true
    var modeFriendship = false
    var modeLanguage = false
    var selectedInterests: Set<String> = []
    var relationshipGoal: String?
    var kids: String?
    var smoking: String?
    var bio = ""
    var nativeLanguageIds: Set<String> = []
    /// Idioma que aprende -> nivel (a1...c2).
    var learningLevels: [String: String] = [:]

    private(set) var step: Step = .name
    private(set) var interests: [InterestItem] = []
    private(set) var languages: [LanguageItem] = []
    private(set) var photos: [PhotoItem] = []
    private(set) var isUploading = false
    static let maxPhotos = 6
    static let minPhotos = 2
    static let maxBio = 500
    private(set) var isSaving = false
    var errorMessage: String?

    private let api: APIClient
    private let session: SessionViewModel

    init(session: SessionViewModel, api: APIClient = .shared) {
        self.session = session
        self.api = api
        if let me = session.me { resume(from: me) }
    }

    /// Rellena el formulario con lo ya guardado y salta al primer paso pendiente.
    private func resume(from me: MeResponse) {
        guard let profile = me.profile else { return }

        displayName = profile.displayName ?? ""
        if let text = profile.birthdate, let date = Self.isoDay.date(from: text) { birthdate = date }
        gender = profile.gender
        datingPreference = profile.datingPreference
        modeDating = profile.modeDating ?? true
        modeFriendship = profile.modeFriendship ?? false
        modeLanguage = profile.modeLanguage ?? false
        selectedInterests = Set(me.interestIds ?? [])
        photos = me.photos ?? []
        for entry in me.languages ?? [] {
            if entry.kind == "native" { nativeLanguageIds.insert(entry.languageId) }
            else { learningLevels[entry.languageId] = entry.level ?? "a1" }
        }
        relationshipGoal = profile.relationshipGoal
        kids = profile.kids
        smoking = profile.smoking
        bio = profile.bio ?? ""

        if displayName.trimmingCharacters(in: .whitespaces).count < 2 { step = .name }
        else if profile.birthdate == nil { step = .birthdate }
        else if gender == nil { step = .gender }
        else if datingPreference == nil { step = .datingPreference }
        else if modeLanguage && nativeLanguageIds.isEmpty { step = .languages }
        else if selectedInterests.count < 3 { step = .interests }
        else if photos.count < Self.minPhotos { step = .photos }
        else { step = .aboutYou }
    }

    /// Los pasos que le tocan a este usuario: "idiomas" solo si activo ese modo.
    var visibleSteps: [Step] {
        Step.allCases.filter { $0 != .languages || modeLanguage }
    }

    var stepNumber: Int { (visibleSteps.firstIndex(of: step) ?? 0) + 1 }

    var progress: Double {
        Double(stepNumber - 1) / Double(max(visibleSteps.count - 1, 1))
    }

    /// Cada paso decide si se puede avanzar. Es la validacion del cliente; el
    /// servidor vuelve a validar (la edad, sobre todo).
    var canAdvance: Bool { canAdvance(at: step) }

    /// Por paso y no solo por el actual: asi la regla de cada uno se puede
    /// comprobar sin tener que recorrer el wizard entero.
    func canAdvance(at step: Step) -> Bool {
        switch step {
        case .name:             displayName.trimmingCharacters(in: .whitespaces).count >= 2
        case .birthdate:        age >= 18
        case .gender:           gender != nil
        case .datingPreference: datingPreference != nil
        case .modes:            modeDating || modeFriendship || modeLanguage
        case .languages:        !nativeLanguageIds.isEmpty
        case .interests:        selectedInterests.count >= 3
        case .photos:           photos.count >= Self.minPhotos && !isUploading
        case .aboutYou:         true
        case .bio:              bio.count <= Self.maxBio
        }
    }

    /// Que falta para poder avanzar. Se ensena bajo el boton apagado.
    var missingHint: String { missingHint(at: step) }

    func missingHint(at step: Step) -> String {
        switch step {
        case .name:             "Escribe tu nombre (minimo 2 letras)."
        case .birthdate:        "Tienes que ser mayor de 18."
        case .gender:           "Elige una opcion."
        case .datingPreference: "Elige una opcion."
        case .modes:            "Elige al menos un modo."
        case .languages:        "Elige al menos un idioma nativo."
        case .interests:        "Elige al menos 3 intereses (llevas \(selectedInterests.count))."
        case .photos:           "Sube al menos \(Self.minPhotos) fotos (llevas \(photos.count))."
        case .bio:              "La bio no puede pasar de \(Self.maxBio) caracteres."
        default:                ""
        }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthdate, to: .now).year ?? 0
    }

    /// La fecha viaja como "yyyy-MM-dd" gregoriano, que es lo que espera el
    /// servidor. Un `DateFormatter` recien hecho usa el calendario y la
    /// numeracion de QUIEN usa el telefono: con el calendario budista o el
    /// japones, el mismo cumpleanos se enviaba con otro ano y el servidor
    /// rechazaba el alta por menor de edad.
    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func loadCatalogs() async {
        if interests.isEmpty {
            do {
                let response: InterestsResponse = try await api.send(.interests)
                interests = response.interests
            } catch {
                errorMessage = "No se pudieron cargar los intereses."
            }
        }
        if languages.isEmpty {
            do {
                let response: LanguagesResponse = try await api.send(.languages)
                languages = response.languages
            } catch {
                errorMessage = "No se pudieron cargar los idiomas."
            }
        }
    }

    // MARK: - Idiomas

    func toggleNative(_ id: String) {
        if nativeLanguageIds.contains(id) { nativeLanguageIds.remove(id) }
        else {
            nativeLanguageIds.insert(id)
            learningLevels[id] = nil
        }
    }

    func toggleLearning(_ id: String) {
        if learningLevels[id] != nil { learningLevels[id] = nil }
        else {
            learningLevels[id] = "a1"
            nativeLanguageIds.remove(id)
        }
    }

    // MARK: - Fotos

    /// Reduce y recomprime antes de subir: una foto de camara pesa varios MB.
    func upload(_ imageData: Data) async {
        guard photos.count < Self.maxPhotos else { return }
        guard let jpeg = Self.jpeg(from: imageData) else {
            errorMessage = "No se pudo leer esa foto."
            return
        }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do {
            let response: PhotoResponse = try await api.upload(
                .uploadPhoto, field: "image", data: jpeg, filename: "photo.jpg", mimeType: "image/jpeg"
            )
            photos.append(response.photo)
        } catch let error as APIError {
            if case .server(_, let message) = error { errorMessage = message }
            else { errorMessage = "No se pudo subir la foto. Intentalo de nuevo." }
        } catch {
            errorMessage = "No se pudo subir la foto. Intentalo de nuevo."
        }
    }

    func removePhoto(_ photo: PhotoItem) async {
        do {
            try await api.send(.photo(id: photo.id))
            photos.removeAll { $0.id == photo.id }
        } catch {
            errorMessage = "No se pudo borrar la foto."
        }
    }

    private static func jpeg(from data: Data, maxSide: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    func toggleInterest(_ id: String) {
        if selectedInterests.contains(id) { selectedInterests.remove(id) }
        else { selectedInterests.insert(id) }
    }

    func back() {
        guard let index = visibleSteps.firstIndex(of: step), index > 0 else { return }
        errorMessage = nil
        step = visibleSteps[index - 1]
    }

    private func goForward() {
        guard let index = visibleSteps.firstIndex(of: step), index + 1 < visibleSteps.count else { return }
        step = visibleSteps[index + 1]
    }

    func next() async {
        guard !isSaving, !isUploading else { return }
        guard canAdvance else {
            errorMessage = missingHint
            return
        }
        errorMessage = nil

        // Las fotos ya se subieron una a una: no hay nada que guardar aqui.
        if step == .photos {
            goForward()
            return
        }

        isSaving = true
        defer { isSaving = false }

        let isLast = step == visibleSteps.last
        do {
            try await api.send(.onboarding, body: payload(finishing: isLast))
            if isLast { session.didCompleteOnboarding() }
            else { goForward() }
        } catch let error as APIError {
            if case .server(_, let message) = error { errorMessage = message }
            else { errorMessage = "No se pudo guardar. Intentalo de nuevo." }
        } catch {
            errorMessage = "No se pudo guardar. Intentalo de nuevo."
        }
    }

    /// Solo se manda lo del paso actual: el servidor hace merge.
    private func payload(finishing: Bool) -> OnboardingPayload {
        var payload = OnboardingPayload()

        switch step {
        case .name:
            payload.displayName = displayName.trimmingCharacters(in: .whitespaces)
        case .birthdate:
            payload.birthdate = Self.isoDay.string(from: birthdate)
        case .gender:
            payload.gender = gender
        case .datingPreference:
            payload.datingPreference = datingPreference
        case .modes:
            payload.modeDating = modeDating
            payload.modeFriendship = modeFriendship
            payload.modeLanguage = modeLanguage
        case .languages:
            payload.languages =
                nativeLanguageIds.map { LanguageEntry(languageId: $0, kind: "native", level: nil) } +
                learningLevels.map { LanguageEntry(languageId: $0.key, kind: "learning", level: $0.value) }
        case .interests:
            payload.interestIds = Array(selectedInterests)
        case .photos:
            break
        case .aboutYou:
            payload.relationshipGoal = relationshipGoal
            payload.kids = kids
            payload.smoking = smoking
        case .bio:
            payload.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if finishing { payload.completed = "true" }
        return payload
    }
}
