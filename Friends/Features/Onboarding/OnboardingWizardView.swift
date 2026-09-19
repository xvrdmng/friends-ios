import SwiftUI

/// Wizard de alta. Cada paso persiste al avanzar, asi que cerrar la app no
/// pierde el progreso.
struct OnboardingWizardView: View {
    let session: SessionViewModel
    @State private var model: OnboardingViewModel?

    var body: some View {
        ZStack {
            DoodleBackground()

            if let model {
                VStack(alignment: .leading, spacing: 20) {
                    header(model)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            OnboardingStepContent(model: model)
                        }
                        .padding(.vertical, 8)
                        .padding(.trailing, 6) // la sombra dura no se corta
                    }
                    .scrollDismissesKeyboard(.interactively)

                    if let message = model.errorMessage {
                        notice(message)
                    }

                    footer(model)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .task {
            if model == nil { model = OnboardingViewModel(session: session) }
            await model?.loadCatalogs()
        }
    }

    private func header(_ model: OnboardingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressBar(progress: model.progress)

            Label {
                Text("PASO \(model.stepNumber) DE \(model.visibleSteps.count)")
            } icon: {
                Image(systemName: "star.fill")
            }
            .font(.system(size: 17, weight: .heavy, design: .monospaced))
            .foregroundStyle(Color.lazyBlack)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .lazyCard(backgroundColor: .lazyYellow, cornerRadius: 12, offset: 3)
            .rotationEffect(.degrees(-3))

            HStack(alignment: .center, spacing: 10) {
                Text(model.step.title.uppercased())
                    .font(.lazyTitle)
                    .foregroundStyle(Color.lazyBlack)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "camera.macro")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.lazyBlack)
                    .frame(width: 38, height: 38)
                    .lazyCard(backgroundColor: .lazyRose, cornerRadius: 19, offset: 2)
            }

            if let subtitle = model.step.subtitle {
                Text(subtitle)
                    .font(.lazyCaption)
                    .foregroundStyle(Color.lazyBlack.opacity(0.65))
            }
        }
    }

    private func notice(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.lazyRed, in: Circle())
                .overlay(Circle().stroke(Color.lazyBlack, lineWidth: 2))
            Text(message)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.lazyBlack)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .lazyCard(backgroundColor: .lazyNotice, cornerRadius: 16, offset: 3)
        .padding(.trailing, 3)
    }

    private func footer(_ model: OnboardingViewModel) -> some View {
        let isLast = model.step == model.visibleSteps.last
        return HStack(spacing: 16) {
            if model.step != .name {
                Button("Atras") { model.back() }
                    .buttonStyle(LazyButtonStyle(background: .white, foreground: .lazyBlack))
                    .disabled(model.isSaving)
            }

            Button {
                Task { await model.next() }
            } label: {
                if model.isSaving {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(isLast ? "Terminar" : "Siguiente")
                        Image(systemName: "arrow.right").font(.system(size: 18, weight: .black))
                    }
                }
            }
            .buttonStyle(LazyButtonStyle(
                background: model.canAdvance ? .lazyRed : Color(hex: "#D9A39C"),
                foreground: .white,
                fillsWidth: true
            ))
            .disabled(model.isSaving)
        }
        .padding(.trailing, 5)
        .padding(.bottom, 5)
    }
}

/// Barra de progreso en pildora: relleno rojo, borde y sombra duros.
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.white
                Capsule()
                    .fill(Color.lazyRed)
                    .overlay(Capsule().stroke(Color.lazyBlack, lineWidth: 2))
                    .padding(4)
                    .frame(width: max(24, min(1, progress) * geo.size.width))
            }
        }
        .frame(height: 26)
        .lazyCard(backgroundColor: .white, cornerRadius: 13, offset: 3)
        .padding(.trailing, 3)
        .animation(.snappy, value: progress)
    }
}
