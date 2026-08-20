import SwiftUI
import PulseShared

struct PermissionsView: View {
    @Bindable var vm: OnboardingViewModel
    var healthEngine: HealthEngine
    @State private var isGranting = false

    private let permissions: [(icon: String, title: String, detail: String)] = [
        ("heart.fill",         "Heart Rate",             "Detect stress and exercise"),
        ("waveform.path.ecg",  "Heart Rate Variability", "Measure recovery and tension"),
        ("moon.fill",          "Sleep Analysis",         "Understand your rest"),
        ("lungs.fill",         "Blood Oxygen",           "Monitor vitality levels"),
        ("figure.walk",        "Activity & Exercise",    "Celebrate your movement"),
        ("bell.fill",          "Notifications",          "Receive verses at the right moment"),
    ]

    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: PSSpacing.xl) {
                        // Header
                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            Text("Let Pulse listen to your body")
                                .font(PSFont.label(size: 28, weight: .bold))
                                .foregroundStyle(Color.psWhite)

                            Text("To deliver the right verse at the right time, we need to read your health data. This data stays on your device — always.")
                                .font(PSFont.label(size: 15))
                                .foregroundStyle(Color.psWhite.opacity(0.75))
                                .lineSpacing(4)
                        }
                        .padding(.top, PSSpacing.xl)

                        // Permission rows
                        VStack(spacing: PSSpacing.md) {
                            ForEach(permissions, id: \.title) { perm in
                                HStack(spacing: PSSpacing.md) {
                                    Image(systemName: perm.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.psAccent)
                                        .frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(perm.title)
                                            .font(PSFont.label(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.psWhite)
                                        Text(perm.detail)
                                            .font(PSFont.label(size: 13))
                                            .foregroundStyle(Color.psWhite.opacity(0.6))
                                    }
                                    Spacer()
                                }
                                .padding(PSSpacing.md)
                                .background(Color.psNavy)
                                .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
                            }
                        }

                        // Limited note if permissions were denied
                        if vm.permissionsLimited {
                            Text("Some features will be limited")
                                .font(PSFont.label(size: 14))
                                .foregroundStyle(Color.psWarning)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.lg)
                }

                // Bottom CTA
                VStack(spacing: PSSpacing.sm) {
                    PSButton(
                        title: isGranting ? "Requesting access…" : "Grant Access",
                        style: .primary
                    ) {
                        guard !isGranting else { return }
                        isGranting = true
                        Task {
                            await vm.grantPermissions(healthEngine: healthEngine)
                            isGranting = false
                        }
                    }
                    .disabled(isGranting)

                    Text("Your privacy is sacred. Read our commitment →")
                        .font(PSFont.label(size: 13))
                        .foregroundStyle(Color.psAccent.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xxl)
                .padding(.top, PSSpacing.md)
                .background(Color.psDeepNavy)
            }
        }
        .onAppear {
            Analytics.shared.track(.onboardingStepViewed(step: "permissions"))
        }
        .trackScreen("Onboarding_Permissions")
    }
}
