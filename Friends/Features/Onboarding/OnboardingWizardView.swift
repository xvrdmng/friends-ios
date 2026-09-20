import SwiftUI

/// Wizard de alta. Cada paso persiste al avanzar, asi que cerrar la app no
/// pierde el progreso.
struct OnboardingWizardView: View {
    let session: SessionViewModel
    @State private var model: OnboardingViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .task {
            if model == nil { model = OnboardingViewModel(session: session) }
            await model?.loadCatalogs()
        }
    }

    private func content(_ model: OnboardingViewModel) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(model)
                    OnboardingStepContent(model: model)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            footer(model)
        }
        .navigationTitle(model.step.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // El progreso vive en la barra para que no se vaya con el scroll.
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 140)
                    .accessibilityLabel("Paso \(model.stepNumber) de \(model.visibleSteps.count)")
            }
        }
        .alert("No se pudo guardar",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } }),
               presenting: model.errorMessage) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func header(_ model: OnboardingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paso \(model.stepNumber) de \(model.visibleSteps.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(model.step.title)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = model.step.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func footer(_ model: OnboardingViewModel) -> some View {
        let isLast = model.step == model.visibleSteps.last
        return VStack(spacing: 10) {
            // Con el boton apagado y nada escrito, lo unico que veia la gente
            // era un "Siguiente" gris que no responde. El motivo ya estaba
            // calculado; solo faltaba ensenarlo.
            if !model.canAdvance && !model.missingHint.isEmpty {
                Label(model.missingHint, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Falta esto para poder seguir")
            }

            HStack(spacing: 12) {
                if model.step != .name {
                    Button("Atrás") { model.back() }
                        .buttonStyle(.glass)
                        .disabled(model.isSaving)
                }

                Button {
                    Task { await model.next() }
                } label: {
                    if model.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(isLast ? "Terminar" : "Siguiente").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(model.isSaving || !model.canAdvance)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .animation(.snappy, value: model.canAdvance)
    }
}
