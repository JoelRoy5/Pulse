import SwiftUI
import PulseShared

// MARK: - FeelingPickerView

/// A sheet that lets the user pick how they're feeling and request a fresh verse
/// for that state. The selection maps to a `BiometricState` and runs the live
/// verse pipeline on the phone (full variety, avoids recent repeats), then syncs
/// to the watch and history like any other delivery.
struct FeelingPickerView: View {
    let onSelect: (Emotion) -> Void

    @Environment(\.dismiss) private var dismiss

    // The 9 picker emotions — all Emotion cases except .unwell (auto-detected only).
    private static let pickerEmotions: [Emotion] = [
        .drained, .restful, .content,
        .weighedDown, .steady, .grateful,
        .stressed, .driven, .energized
    ]

    private let columns = [GridItem(.flexible(), spacing: PSSpacing.md),
                           GridItem(.flexible(), spacing: PSSpacing.md)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.psDeepNavy.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text("How are you feeling right now?")
                            .font(PSFont.label(size: 20, weight: .bold))
                            .foregroundStyle(Color.psWhite)
                            .padding(.top, PSSpacing.sm)

                        Text("We'll find a verse to meet you there.")
                            .font(PSFont.label(size: 14))
                            .foregroundStyle(Color.psGrayMuted)

                        LazyVGrid(columns: columns, spacing: PSSpacing.md) {
                            ForEach(Self.pickerEmotions) { emotion in
                                Button {
                                    Analytics.shared.track(.feelingPicked(emotion: emotion.rawValue))
                                    onSelect(emotion)
                                    dismiss()
                                } label: {
                                    VStack(spacing: PSSpacing.sm) {
                                        Image(systemName: emotion.systemImage)
                                            .font(.system(size: 26))
                                            .foregroundStyle(Color.psAccent)
                                        Text(emotion.displayName)
                                            .font(PSFont.label(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.psWhite)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, PSSpacing.lg)
                                    .background(Color.psNavy)
                                    .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, PSSpacing.sm)
                    }
                    .padding(PSSpacing.screenHorizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.psAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Analytics.shared.track(.feelingPickerOpened)
        }
    }
}
