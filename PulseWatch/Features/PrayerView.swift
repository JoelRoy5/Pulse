import SwiftUI
import WatchKit
import PulseShared

// MARK: - PrayerView

struct PrayerView: View {
    @Environment(WatchState.self) private var watchState
    @State private var selectedFeeling: PrayerFeeling?
    @State private var showResponse = false
    @State private var showPrayerSession = false

    enum PrayerFeeling: String, CaseIterable {
        case grateful = "Grateful"
        case struggling = "Struggling"
        case atPeace = "At Peace"
        case needHelp = "Need Help"

        var systemImageName: String {
            switch self {
            case .grateful:   return "hands.and.sparkles.fill"
            case .struggling: return "cloud.rain.fill"
            case .atPeace:    return "leaf.fill"
            case .needHelp:   return "exclamationmark.bubble.fill"
            }
        }

        var biometricState: BiometricState {
            switch self {
            case .grateful:   return .deepRestRecovered
            case .struggling: return .sadWithdrawn
            case .atPeace:    return .peacefulSteady
            case .needHelp:   return .stressedAnxious
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "hands.and.sparkles.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.psAccent)
                    .padding(.top, 4)

                Text("How are you\nfeeling right now?")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // 2×2 feeling buttons
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        feelingButton(.grateful)
                        feelingButton(.struggling)
                    }
                    HStack(spacing: 6) {
                        feelingButton(.atPeace)
                        feelingButton(.needHelp)
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.2))
                    .padding(.vertical, 2)

                // A Time of Prayer (Phase 2)
                Button {
                    WKInterfaceDevice.current().play(.click)
                    showPrayerSession = true
                } label: {
                    Text("Begin a Time of Prayer")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.psAccent)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(Color.psDeepNavy.ignoresSafeArea())
        .sheet(item: $selectedFeeling) { feeling in
            PrayerResponseSheet(feeling: feeling)
        }
        .fullScreenCover(isPresented: $showPrayerSession) {
            PrayerTimeView(currentVerse: watchState.currentVerse)
        }
    }

    @ViewBuilder
    private func feelingButton(_ feeling: PrayerFeeling) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            selectedFeeling = feeling
        } label: {
            VStack(spacing: 3) {
                Image(systemName: feeling.systemImageName)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.psAccent)
                Text(feeling.rawValue)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.psNavy)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PrayerFeeling Identifiable

extension PrayerView.PrayerFeeling: Identifiable {
    var id: String { rawValue }
}

// MARK: - Prayer Response Sheet

private struct PrayerResponseSheet: View {
    let feeling: PrayerView.PrayerFeeling

    // nil while the live request is in flight; then a live verse (from the phone)
    // or a local bundled fallback when the phone is unreachable.
    @State private var verse: BibleVerse?

    private var localFallback: BibleVerse {
        FallbackVerseProvider().emergencyVerse(for: feeling.biometricState)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: feeling.systemImageName)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                    Text(feeling.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                Divider().overlay(.white.opacity(0.2))

                if let verse {
                    // Verse text
                    Text(verse.text)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verse.reference)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    HStack {
                        ProgressView()
                        Text("Finding a verse\u{2026}")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(feeling.biometricState.gradient)
        .task {
            // Ask the phone for a live, varied verse; fall back locally if it's
            // unreachable or the request fails.
            let payload = await WatchSessionManager.shared.requestVerse(for: feeling.biometricState)
            verse = payload.map {
                BibleVerse(
                    id: $0.deliveryID,
                    reference: $0.verseReference,
                    text: $0.verseText,
                    translationAbbreviation: $0.translationAbbreviation,
                    copyright: "",
                    chapterURLString: nil
                )
            } ?? localFallback
        }
    }
}
