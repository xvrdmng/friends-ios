import SwiftUI

/// Wizard de alta, 13 pasos. Cada paso persiste con PATCH /me/onboarding, así que
/// cerrar la app no pierde el progreso: se vuelve al mismo paso.
struct OnboardingWizardView: View {
    let session: SessionViewModel

    enum Step: Int, CaseIterable {
        case name, birthdate, gender, datingPreference, modes, photos,
             interests, aboutYou, languages, bio, permissions, recovery, done

        var title: String {
            switch self {
            case .name:             "¿Cómo te llamas?"
            case .birthdate:        "¿Cuándo naciste?"
            case .gender:           "¿Cuál es tu género?"
            case .datingPreference: "¿Quién te interesa?"
            case .modes:            "¿A qué vienes?"
            case .photos:           "Tus fotos"
            case .interests:        "¿Qué te gusta hacer?"
            case .aboutYou:         "Sobre ti"
            case .languages:        "Idiomas"
            case .bio:              "Cuéntate"
            case .permissions:      "Permisos"
            case .recovery:         "Recuperación"
            case .done:             "Listo"
            }
        }
    }

    @State private var step: Step = .name

    var body: some View {
        ZStack {
            Color.lazyHeroBG.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                ProgressBar(progress: Double(step.rawValue) / Double(Step.allCases.count - 1))

                Text("PASO \(step.rawValue + 1) DE \(Step.allCases.count)")
                    .font(.lazyMono)

                Text(step.title)
                    .font(.lazyTitle)

                Spacer()
            }
            .padding(24)
        }
    }
}

/// Barra de progreso en estilo sticker, no la del sistema.
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.white)
                Rectangle()
                    .fill(Color.lazyAcid)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 18)
        .lazyCard(backgroundColor: .clear, cornerRadius: 4, offset: 3)
    }
}
