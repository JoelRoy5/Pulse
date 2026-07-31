import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "PulseApp")

@main
struct PulseApp: App {

    private let container: ModelContainer
    @State private var engine = HealthEngine()

    init() {
        do {
            container = try ModelContainer.makePulseContainer()
        } catch {
            logger.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public). Using in-memory fallback.")
            // Last-resort in-memory container — must not crash
            let schema = Schema([VerseDelivery.self, CachedVerse.self, UserPreferences.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [config]))
                ?? { fatalError("Cannot create even an in-memory ModelContainer") }()
        }
    }

    var body: some Scene {
        WindowGroup {
            DebugHomeView()
                .environment(engine)
        }
        .modelContainer(container)
    }
}

// MARK: - Debug Home View (Task 9 placeholder — replaced in Task 10)

private struct DebugHomeView: View {
    @Environment(HealthEngine.self) private var engine

    var body: some View {
        VStack(spacing: 20) {
            Text(engine.currentClassification?.state.displayName ?? "—")
                .font(.largeTitle)
                .bold()

            if let classification = engine.currentClassification {
                Text(String(format: "Confidence: %.0f%%", classification.confidence * 100))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let snapshot = engine.currentSnapshot {
                    Text(String(format: "Data completeness: %.0f%%", snapshot.dataCompleteness * 100))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap to refresh")
                    .foregroundStyle(.secondary)
            }

            Button("Refresh") {
                Task { await engine.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task {
            try? await engine.requestAuthorization()
            await engine.refresh()
        }
    }
}
