import SwiftUI
import PulseShared

// MARK: - HistoryDetailView
//
// A thin wrapper around VerseDetailSheet that also surfaces the additional
// fields called for by doc-05:275-283:
//   - Time delivered
//   - Reaction shown alongside
//
// The bulk of the UI is delegated to VerseDetailSheet (Task 15).

struct HistoryDetailView: View {
    let delivery: VerseDelivery
    let preferredBibleID: Int
    let onReact: (VerseReaction) -> Void
    let onShare: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VerseDetailSheet(
            delivery: delivery,
            preferredBibleID: preferredBibleID,
            onReact: onReact,
            onShare: onShare
        )
    }
}
