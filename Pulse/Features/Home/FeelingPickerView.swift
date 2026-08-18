import SwiftUI
import PulseShared

// MARK: - FeelingPickerView

/// A sheet that lets the user pick how they're feeling and request a fresh verse
/// for that state. The selection maps to a `BiometricState` and runs the live
/// verse pipeline on the phone (full variety, avoids recent repeats), then syncs
/// to the watch and history like any other delivery.
struct FeelingPickerView: View {
    let onSelect: (BiometricState) -> Void

    @Environment(\.dismiss) private var dismiss

    enum Feeling: String, CaseIterable, Identifiable {
        case grateful = "Grateful"
        case anxious  = "Anxious"
        case weary    = "Weary"
        case sad      = "Sad"
        case atPeace  = "At Peace"
        case joyful   = "Joyful"

        var id: String { rawValue }

        var state: BiometricState {
            switch self {
            case .grateful: return .deepRestRecovered
            case .anxious:  return .stressedAnxious
            case .weary:    return .exhaustedDepleted
            case .sad:      return .sadWithdrawn
            case .atPeace:  return .peacefulSteady
            case .joyful:   return .energizedPostWorkout
            }
        }

        var systemImage: String {
            switch self {
            case .grateful: return "hands.and.sparkles.fill"
            case .anxious:  return "wind"
            case .weary:    return "moon.zzz.fill"
            case .sad:      return "cloud.rain.fill"
            case .atPeace:  return "leaf.fill"
            case .joyful:   return "sun.max.fill"
            }
        }
    }

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
                            ForEach(Feeling.allCases) { feeling in
                                Button {
                                    onSelect(feeling.state)
                                    dismiss()
                                } label: {
                                    VStack(spacing: PSSpacing.sm) {
                                        Image(systemName: feeling.systemImage)
                                            .font(.system(size: 26))
                                            .foregroundStyle(Color.psAccent)
                                        Text(feeling.rawValue)
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
    }
}
