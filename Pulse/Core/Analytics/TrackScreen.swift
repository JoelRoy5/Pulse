import SwiftUI

// MARK: - TrackScreenModifier

/// A ViewModifier that fires `screen_viewed` analytics events on appear and
/// disappear. On appear: records the timestamp and sends `durationS: nil`.
/// On disappear: computes elapsed seconds and sends the dwell event.
private struct TrackScreenModifier: ViewModifier {
    let name: String
    @State private var appearTime: Date? = nil

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTime = Date()
                Analytics.shared.track(.screenViewed(screen: name, durationS: nil))
            }
            .onDisappear {
                guard let appeared = appearTime else { return }
                let elapsed = Int(Date().timeIntervalSince(appeared))
                Analytics.shared.track(.screenViewed(screen: name, durationS: elapsed))
                appearTime = nil
            }
    }
}

// MARK: - View Extension

extension View {
    /// Tracks screen views via PostHog `screen_viewed` events.
    /// Fires once on `.onAppear` (durationS: nil) and once on `.onDisappear`
    /// (durationS: elapsed seconds since appear).
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(name: name))
    }
}
