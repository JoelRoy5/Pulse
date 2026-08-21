#if DEBUG
import SwiftUI
import PulseShared

// MARK: - AnalyticsInspectorView

/// DEBUG-only view that shows the last 100 analytics events recorded in this
/// session. Useful for verifying that the right events fire as you navigate
/// the app. Events marked with a yellow dot were NOT sent to PostHog (either
/// analytics is disabled or PostHog is not configured).
struct AnalyticsInspectorView: View {

    @State private var log = AnalyticsDebugLog.shared

    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()

            if log.events.isEmpty {
                emptyState
            } else {
                eventList
            }
        }
        .navigationTitle("Analytics Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.psDeepNavy, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    log.clear()
                }
                .foregroundStyle(Color.psAccent)
                .disabled(log.events.isEmpty)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color.psGrayMuted)
            Text("No events yet")
                .font(PSFont.label(size: 16, weight: .semibold))
                .foregroundStyle(Color.psWhite)
            Text("Tap around the app to see events appear here.")
                .font(PSFont.label(size: 13))
                .foregroundStyle(Color.psGrayMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        List(log.events) { event in
            eventRow(event)
                .listRowBackground(Color.psNavy)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    // MARK: - Event Row

    private func eventRow(_ event: RecordedEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Sent indicator
                Circle()
                    .fill(event.wasSent ? Color.psSuccess : Color.psAlert)
                    .frame(width: 7, height: 7)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }

                Text(event.name)
                    .font(PSFont.label(size: 14, weight: .semibold))
                    .foregroundStyle(Color.psWhite)

                Spacer()

                Text(relativeTime(event.at))
                    .font(PSFont.label(size: 12))
                    .foregroundStyle(Color.psGrayMuted)
            }

            if !event.props.isEmpty {
                Text(compactProps(event.props))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.psGrayMuted)
                    .lineLimit(2)
                    .padding(.leading, 13)
            }

            if !event.wasSent {
                Text("not sent (disabled or unconfigured)")
                    .font(PSFont.label(size: 11))
                    .foregroundStyle(Color.psAlert)
                    .padding(.leading, 13)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }

    private func compactProps(_ props: [String: Any]) -> String {
        let pairs = props.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }
        return pairs.joined(separator: "  ")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnalyticsInspectorView()
    }
}
#endif
