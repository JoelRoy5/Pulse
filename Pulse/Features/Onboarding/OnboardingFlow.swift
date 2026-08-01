import SwiftUI
import SwiftData
import PulseShared

struct OnboardingFlow: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine
    @Environment(\.modelContext) private var modelContext

    var onComplete: () -> Void

    @State private var vm: OnboardingViewModel

    init(startStep: OnboardingViewModel.Step = .welcome, onComplete: @escaping () -> Void) {
        self._vm = State(initialValue: OnboardingViewModel(step: startStep))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            switch vm.step {
            case .welcome:
                WelcomeView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .permissions:
                PermissionsView(vm: vm, healthEngine: healthEngine)
                    .transition(.psSlideUp)
            case .translation:
                TranslationPickerView(vm: vm) {
                    Task {
                        await vm.finish(
                            healthEngine: healthEngine,
                            scriptureEngine: scriptureEngine,
                            modelContext: modelContext
                        )
                    }
                }
                .transition(.psSlideUp)
            case .complete:
                OnboardingCompleteView(vm: vm, onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.step)
    }
}
