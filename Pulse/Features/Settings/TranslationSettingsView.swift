import SwiftUI
import PulseShared

// MARK: - TranslationSettingsView

struct TranslationSettingsView: View {
    @Bindable var vm: SettingsViewModel

    @State private var previewCache: [Int: String] = [:]
    @State private var previewText: String? = nil
    @State private var isLoadingPreview: Bool = false

    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Bible Translation")
                        .font(PSFont.label(size: 26, weight: .bold))
                        .foregroundStyle(Color.psWhite)

                    Text("Choose the translation that speaks to your heart.")
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psWhite.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.xl)
                .padding(.bottom, PSSpacing.lg)

                if vm.isLoadingTranslations {
                    ProgressView()
                        .tint(Color.psAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: PSSpacing.sm) {
                            ForEach(vm.availableTranslations) { version in
                                translationCard(version: version)
                            }
                        }
                        .padding(.horizontal, PSSpacing.screenHorizontal)
                        .padding(.bottom, PSSpacing.lg)
                    }
                }

                // Preview area
                previewArea
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.md)
            }
        }
        .navigationTitle("Translation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.psDeepNavy, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if vm.availableTranslations.isEmpty {
                await vm.loadTranslations()
            }
            await loadPreview(for: vm.preferredBibleID, abbreviation: vm.preferredBibleAbbreviation)
        }
    }

    // MARK: - Translation Card

    private func translationCard(version: BibleVersion) -> some View {
        let isSelected = vm.preferredBibleID == version.id
        return Button {
            vm.selectTranslation(version)
            Task {
                await loadPreview(for: version.id, abbreviation: version.abbreviation)
            }
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

    // MARK: - Preview Area

    @ViewBuilder
    private var previewArea: some View {
        VStack(spacing: PSSpacing.xs) {
            if isLoadingPreview {
                ProgressView()
                    .tint(Color.psAccent)
                    .frame(height: 60)
            } else if let text = previewText {
                Text(text)
                    .font(PSFont.verseText(size: 15))
                    .foregroundStyle(Color.psWhite.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .id(vm.preferredBibleID)
            }
        }
        .frame(minHeight: 70)
        .animation(.easeInOut(duration: 0.3), value: vm.preferredBibleID)
    }

    // MARK: - Preview Loading

    private func loadPreview(for bibleID: Int, abbreviation: String) async {
        if let cached = previewCache[bibleID] {
            previewText = cached
            return
        }
        isLoadingPreview = true
        previewText = nil
        let client = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        do {
            let verse = try await client.fetchVerse(
                reference: "Psalm 23:1",
                bibleID: bibleID,
                abbreviation: abbreviation
            )
            previewCache[bibleID] = verse.text
            previewText = verse.text
        } catch {
            previewText = "The Lord is my shepherd — \(abbreviation)"
        }
        isLoadingPreview = false
    }
}
