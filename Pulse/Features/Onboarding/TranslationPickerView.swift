import SwiftUI
import PulseShared

struct TranslationPickerView: View {
    @Bindable var vm: OnboardingViewModel
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Which translation speaks to your heart?")
                        .font(PSFont.label(size: 26, weight: .bold))
                        .foregroundStyle(Color.psWhite)

                    Text("You can always change this later.")
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psWhite.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.xl)
                .padding(.bottom, PSSpacing.lg)

                // Translation cards
                ScrollView {
                    VStack(spacing: PSSpacing.sm) {
                        ForEach(vm.availableTranslations) { version in
                            translationCard(version: version)
                        }
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.lg)
                }

                // Preview text area (crossfade on change)
                previewArea
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.md)

                // Continue button
                PSButton(
                    title: "Continue with \(vm.selectedTranslation.abbreviation) →",
                    style: .primary
                ) {
                    onContinue()
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xxl)
            }
        }
        .task {
            await vm.loadTranslations()
        }
        .trackScreen("Onboarding_Translation")
    }

    // MARK: - Subviews

    private func translationCard(version: BibleVersion) -> some View {
        let isSelected = vm.selectedTranslation.id == version.id
        return Button {
            Task { await vm.selectTranslation(version) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: PSSpacing.sm) {
                        Text(version.abbreviation)
                            .font(PSFont.label(size: 15, weight: .bold))
                            .foregroundStyle(isSelected ? Color.psAccent : Color.psWhite)
                        Text(version.title)
                            .font(PSFont.label(size: 14))
                            .foregroundStyle(Color.psWhite.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .frame(minHeight: 44)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                }
            }
            .padding(PSSpacing.md)
            .background(isSelected ? Color.psNavy : Color.psNavy.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: PSRadius.md)
                    .stroke(isSelected ? Color.psAccent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewArea: some View {
        VStack(spacing: PSSpacing.xs) {
            if vm.isLoadingPreview {
                ProgressView()
                    .tint(Color.psAccent)
                    .frame(height: 60)
            } else if let text = vm.previewVerseText {
                Text(text)
                    .font(PSFont.verseText(size: 15))
                    .foregroundStyle(Color.psWhite.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.animation(.psVerseTransition))
                    .id(vm.selectedTranslation.id) // force crossfade on change
            }
        }
        .frame(minHeight: 70)
        .animation(.psVerseTransition, value: vm.selectedTranslation.id)
    }
}
