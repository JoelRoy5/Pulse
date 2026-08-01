import SwiftUI
import PulseShared

// MARK: - ShareCardRenderer
//
// Renders a ShareCardCanvas to a UIImage using ImageRenderer at display scale 3
// targeting approximately 1080×1350 pixels.

enum ShareCardRenderer {

    static func render(
        delivery: VerseDelivery,
        variant: ShareCardVariant,
        includeStateContext: Bool
    ) async -> UIImage {
        await MainActor.run {
            let canvas = ShareCardCanvas(
                delivery: delivery,
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
        let image = ImageRenderer(
            content: ShareCardCanvas(
                delivery: delivery,
                variant: .night,
                includeStateContext: false
            )
            .frame(width: 360, height: 450)
        )
        image.scale = 3.0
        if let uiImage = image.uiImage,
           let data = uiImage.pngData() {
            // Save to Documents (accessible via simctl) and /tmp (works on macOS, not simulator sandbox)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let docsURL = docs {
                try? data.write(to: docsURL.appendingPathComponent("task16-share-night.png"))
            }
        }
    }

    /// Saves the Classic variant to the app's Documents directory for retrieval.
    @MainActor
    static func saveClassicVariantDebug(delivery: VerseDelivery) {
        let image = ImageRenderer(
            content: ShareCardCanvas(
                delivery: delivery,
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
