import SwiftUI
import PulseShared

// MARK: - ShareCardSnapshot
//
// A lightweight Sendable value type capturing only the fields needed to render
// a share card. Built on the MainActor from a VerseDelivery @Model so the
// model object never crosses a concurrency boundary.

struct ShareCardSnapshot: Sendable {
    let verseText: String
    let verseReference: String
    let translationAbbreviation: String
    let stateName: String        // e.g. "Exhausted & Depleted"
    let stateSymbol: String      // SF Symbol name, e.g. "moon.fill"
    let contextLine: String      // stateBodyText
    let isOfflineFallback: Bool

    @MainActor
    init(from delivery: VerseDelivery) {
        self.verseText = delivery.verseText
        self.verseReference = delivery.verseReference
        self.translationAbbreviation = delivery.translationAbbreviation
        let state = delivery.biometricState ?? .peacefulSteady
        self.stateName = delivery.emotion.displayName
        self.stateSymbol = state.systemImageName
        self.contextLine = delivery.stateBodyText
        self.isOfflineFallback = delivery.isOfflineFallback
    }
}

// MARK: - ShareCardRenderer
//
// Renders a ShareCardCanvas to a UIImage using ImageRenderer at display scale 3
// targeting approximately 1080×1350 pixels.
//
// The render function accepts a pre-built ShareCardSnapshot (a plain Sendable
// struct) rather than the VerseDelivery @Model, so no SwiftData model crosses
// a concurrency boundary.

enum ShareCardRenderer {

    /// Build a snapshot from a delivery on the MainActor, then render the card.
    @MainActor
    static func render(
        delivery: VerseDelivery,
        variant: ShareCardVariant,
        includeStateContext: Bool
    ) async -> UIImage {
        let snapshot = ShareCardSnapshot(from: delivery)
        return await render(snapshot: snapshot, variant: variant, includeStateContext: includeStateContext)
    }

    /// Render from a pre-built snapshot — safe to call from any isolation.
    static func render(
        snapshot: ShareCardSnapshot,
        variant: ShareCardVariant,
        includeStateContext: Bool
    ) async -> UIImage {
        await MainActor.run {
            let canvas = ShareCardCanvas(
                snapshot: snapshot,
                variant: variant,
                includeStateContext: includeStateContext
            )
            // Target ~1080×1350 logical — 360×450 @3x
            let renderer = ImageRenderer(content: canvas.frame(width: 360, height: 450))
            renderer.scale = 3.0
            return renderer.uiImage ?? UIImage()
        }
    }

    // MARK: - Debug: render night variant to disk

    /// Saves the Night variant to the app's Documents directory for retrieval.
    /// Called in debug builds via -PulseSaveShareDebug YES.
    @MainActor
    static func saveNightVariantDebug(delivery: VerseDelivery) {
        let snapshot = ShareCardSnapshot(from: delivery)
        let image = ImageRenderer(
            content: ShareCardCanvas(
                snapshot: snapshot,
                variant: .night,
                includeStateContext: false
            )
            .frame(width: 360, height: 450)
        )
        image.scale = 3.0
        if let uiImage = image.uiImage,
           let data = uiImage.pngData() {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let docsURL = docs {
                try? data.write(to: docsURL.appendingPathComponent("task16-share-night.png"))
            }
        }
    }

    /// Saves the Classic variant to the app's Documents directory for retrieval.
    @MainActor
    static func saveClassicVariantDebug(delivery: VerseDelivery) {
        let snapshot = ShareCardSnapshot(from: delivery)
        let image = ImageRenderer(
            content: ShareCardCanvas(
                snapshot: snapshot,
                variant: .classic,
                includeStateContext: false
            )
            .frame(width: 360, height: 450)
        )
        image.scale = 3.0
        if let uiImage = image.uiImage,
           let data = uiImage.pngData() {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let docsURL = docs {
                try? data.write(to: docsURL.appendingPathComponent("task16-share-classic.png"))
            }
        }
    }
}
