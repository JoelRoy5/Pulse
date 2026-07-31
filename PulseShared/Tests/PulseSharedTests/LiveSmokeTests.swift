import XCTest
@testable import PulseShared

// MARK: - LiveSmokeTests
//
// Skipped unless env PULSE_LIVE_SMOKE=1.
// Run: PULSE_LIVE_SMOKE=1 swift test --package-path PulseShared --filter LiveSmokeTests
//
// Reads credentials from ../Config/Debug.xcconfig (relative to PulseShared package root).
// Skips if file or keys are missing.

final class LiveSmokeTests: XCTestCase {

    // MARK: - Credential Loading

    struct Credentials {
        let glooClientID: String
        let glooClientSecret: String
        let youVersionAppKey: String
    }

    /// Parses ../Config/Debug.xcconfig relative to PulseShared package root.
    /// The package is at PulseShared/, so Config/ is one level up.
    static func loadCredentials() -> Credentials? {
        // __FILE__ is inside PulseShared/Tests/... so we navigate up to PulseShared then ../Config
        // Use Bundle or derive from #file
        let thisFile = #file  // .../PulseShared/Tests/PulseSharedTests/LiveSmokeTests.swift
        let thisURL = URL(fileURLWithPath: thisFile)
        // Go up: LiveSmokeTests.swift → PulseSharedTests → Tests → PulseShared → project root
        // Config/Debug.xcconfig lives at ../Config/Debug.xcconfig relative to PulseShared/
        let configURL = thisURL
            .deletingLastPathComponent() // PulseSharedTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // PulseShared (package root)
            .deletingLastPathComponent() // project root (one level above PulseShared)
            .appendingPathComponent("Config/Debug.xcconfig")

        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return nil
        }

        var values: [String: String] = [:]
        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            values[key] = value
        }

        guard
            let clientID = values["GLOO_CLIENT_ID"], !clientID.isEmpty, clientID != "your_gloo_client_id_here",
            let clientSecret = values["GLOO_CLIENT_SECRET"], !clientSecret.isEmpty, clientSecret != "your_gloo_client_secret_here",
            let appKey = values["YOUVERSION_APP_KEY"], !appKey.isEmpty, appKey != "your_youversion_app_key_here"
        else {
            return nil
        }

        return Credentials(
            glooClientID: clientID,
            glooClientSecret: clientSecret,
            youVersionAppKey: appKey
        )
    }

    // MARK: - Smoke Test

    func testLiveGlooAndYouVersion() async throws {
        // Skip unless explicitly opted in
        guard ProcessInfo.processInfo.environment["PULSE_LIVE_SMOKE"] == "1" else {
            throw XCTSkip("Set PULSE_LIVE_SMOKE=1 to run live smoke tests")
        }

        guard let creds = Self.loadCredentials() else {
            throw XCTSkip("Config/Debug.xcconfig missing or keys not filled in — skipping live smoke test")
        }

        print("\n[LiveSmokeTest] Starting live smoke test...")

        // Step 1: Ask Gloo AI for a verse for 'exhausted_depleted'
        let glooClient = GlooAIClient(clientID: creds.glooClientID, clientSecret: creds.glooClientSecret)
        let context = VerseSelectionContext(
            state: .exhaustedDepleted,
            timeOfDay: TimeOfDay(date: Date()),
            confidence: 0.88,
            recentStates: [.peacefulSteady],
            translation: .NIV,
            preferredThemes: ["rest_renewal"],
            avoidRepeats: []
        )

        print("[LiveSmokeTest] Calling Gloo AI for state: exhausted_depleted...")
        let selection: VerseSelection
        do {
            selection = try await glooClient.selectVerse(for: context)
            print("[LiveSmokeTest] Gloo returned reference: \(selection.reference)")
            print("[LiveSmokeTest] Theme: \(selection.theme) — \(selection.themeDisplayName)")
            if let rationale = selection.rationale {
                print("[LiveSmokeTest] Rationale: \(rationale)")
            }
        } catch {
            XCTFail("[LiveSmokeTest] Gloo AI call failed: \(error)")
            return
        }

        // Step 2: Fetch that reference from YouVersion (BSB 3034)
        let youVersionClient = YouVersionClient(appKey: creds.youVersionAppKey)
        let referenceToFetch = selection.reference
        print("[LiveSmokeTest] Fetching '\(referenceToFetch)' from YouVersion BSB (3034)...")

        do {
            let verse = try await youVersionClient.fetchVerse(
                reference: referenceToFetch,
                bibleID: DefaultBible.id,
                abbreviation: DefaultBible.abbreviation
            )
            print("[LiveSmokeTest] YouVersion returned verse:")
            print("[LiveSmokeTest]   Reference: \(verse.reference)")
            print("[LiveSmokeTest]   Text: \(verse.text)")
            print("[LiveSmokeTest]   Translation: \(verse.translationAbbreviation)")
            XCTAssertFalse(verse.text.isEmpty, "Verse text should not be empty")
            print("[LiveSmokeTest] SUCCESS — both APIs working correctly")
        } catch ScriptureAPIError.requestFailed(let status) where status == 404 {
            // Gloo's chosen reference might not exist in BSB 3034; fall back to Matthew 11:28
            print("[LiveSmokeTest] \(referenceToFetch) returned 404 in BSB 3034; falling back to Matthew 11:28")
            let fallbackVerse = try await youVersionClient.fetchVerse(
                reference: "Matthew 11:28",
                bibleID: DefaultBible.id,
                abbreviation: DefaultBible.abbreviation
            )
            print("[LiveSmokeTest] Fallback verse text: \(fallbackVerse.text)")
            XCTAssertFalse(fallbackVerse.text.isEmpty, "Fallback verse text should not be empty")
            print("[LiveSmokeTest] SUCCESS — YouVersion path confirmed via fallback")
        } catch {
            XCTFail("[LiveSmokeTest] YouVersion call failed: \(error)")
        }
    }
}
