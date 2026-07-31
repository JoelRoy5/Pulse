import XCTest
@testable import PulseShared

final class GlooAIClientTests: XCTestCase {

    // MARK: - Happy Path

    func testSelectVerseParsesModelJSON() async throws {
        // Gloo OAuth2 token endpoint: POST /oauth2/token → 200 + access_token
        // Gloo completions endpoint: POST /ai/v2/chat/completions → 200 + chat response
        // containing JSON with verse_reference, theme, theme_display_name, rationale, alternates.

        var requestCount = 0
        var capturedCompletionBody: Data?

        StubURLProtocol.requestHandler = { request in
            requestCount += 1
            let anyURL = URL(string: "https://example.com")!

            if requestCount == 1 {
                // Token request
                XCTAssertTrue(request.url?.path.contains("oauth2/token") == true)
                let tokenJSON = """
                {"access_token":"test-token-abc","token_type":"Bearer","expires_in":3600}
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), tokenJSON)
            } else {
                // Completions request — body may be in httpBodyStream when going through URLProtocol
                capturedCompletionBody = requestBody(request)
                let modelContent = """
                {"verse_reference":"Matthew 11:28","theme":"rest_renewal","theme_display_name":"Rest & Renewal","rationale":"Jesus invites the weary to find rest in him.","alternates":["Psalm 23:1","Isaiah 40:31"]}
                """
                let completionJSON = """
                {
                  "id": "chatcmpl-test",
                  "object": "chat.completion",
                  "choices": [
                    {
                      "index": 0,
                      "finish_reason": "stop",
                      "message": {
                        "role": "assistant",
                        "content": \(Self.jsonString(modelContent))
                      }
                    }
                  ]
                }
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), completionJSON)
            }
        }

        let session = stubbedSession()
        let client = GlooAIClient(clientID: "test-id", clientSecret: "test-secret", session: session)

        let context = VerseSelectionContext(
            state: .exhaustedDepleted,
            timeOfDay: .evening,
            confidence: 0.91,
            recentStates: [.peacefulSteady],
            translation: .NIV,
            preferredThemes: ["rest_renewal"],
            avoidRepeats: ["Psalm 46:10"]
        )

        let selection = try await client.selectVerse(for: context)

        XCTAssertEqual(selection.reference, "Matthew 11:28")
        XCTAssertEqual(selection.theme, "rest_renewal")
        XCTAssertEqual(selection.themeDisplayName, "Rest & Renewal")
        XCTAssertFalse(selection.isFallback)
        XCTAssertEqual(requestCount, 2)

        // Verify the completion request body contains exhausted_depleted
        // and does NOT contain raw health field names (heartRate, hrv, bpm, etc.)
        if let body = capturedCompletionBody,
           let bodyString = String(data: body, encoding: .utf8) {
            XCTAssertTrue(bodyString.contains("exhausted_depleted"), "Request body must include state raw value")
            XCTAssertFalse(bodyString.contains("heartRate"), "Must not include raw health metric")
            XCTAssertFalse(bodyString.contains("hrv"), "Must not include raw health metric")
            XCTAssertFalse(bodyString.contains("bpm"), "Must not include raw health metric")
        } else {
            XCTFail("Completion request had no body")
        }
    }

    // MARK: - Garbage Output

    func testGarbageModelOutputThrowsDecodingFailed() async {
        var requestCount = 0
        StubURLProtocol.requestHandler = { request in
            requestCount += 1
            let anyURL = URL(string: "https://example.com")!
            if requestCount == 1 {
                let tokenJSON = """
                {"access_token":"tok","token_type":"Bearer","expires_in":3600}
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), tokenJSON)
            } else {
                let completionJSON = """
                {
                  "choices": [
                    {"message": {"role": "assistant", "content": "I think Psalm 23 is nice"}}
                  ]
                }
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), completionJSON)
            }
        }

        let client = GlooAIClient(clientID: "id", clientSecret: "secret", session: stubbedSession())
        let context = VerseSelectionContext(
            state: .stressedAnxious,
            timeOfDay: .morning,
            confidence: 0.8
        )

        do {
            _ = try await client.selectVerse(for: context)
            XCTFail("Expected decodingFailed but got no error")
        } catch ScriptureAPIError.decodingFailed {
            // Expected
        } catch {
            XCTFail("Expected .decodingFailed, got \(error)")
        }
    }

    // MARK: - HTTP 500

    func testHTTP500ThrowsRequestFailed() async {
        var requestCount = 0
        StubURLProtocol.requestHandler = { request in
            requestCount += 1
            let anyURL = URL(string: "https://example.com")!
            if requestCount == 1 {
                // Token succeeds
                let tokenJSON = """
                {"access_token":"tok","token_type":"Bearer","expires_in":3600}
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), tokenJSON)
            } else {
                // Completions returns 500
                return (makeHTTPResponse(url: anyURL, status: 500), Data())
            }
        }

        let client = GlooAIClient(clientID: "id", clientSecret: "secret", session: stubbedSession())
        let context = VerseSelectionContext(
            state: .peacefulSteady,
            timeOfDay: .afternoon,
            confidence: 0.75
        )

        do {
            _ = try await client.selectVerse(for: context)
            XCTFail("Expected requestFailed but got no error")
        } catch ScriptureAPIError.requestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Expected .requestFailed(500), got \(error)")
        }
    }

    // MARK: - Markdown fence stripping

    func testMarkdownFencedJSONIsParsed() async throws {
        var requestCount = 0
        StubURLProtocol.requestHandler = { request in
            requestCount += 1
            let anyURL = URL(string: "https://example.com")!
            if requestCount == 1 {
                let tokenJSON = """
                {"access_token":"tok","token_type":"Bearer","expires_in":3600}
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), tokenJSON)
            } else {
                let fencedContent = "```json\\n{\\\"verse_reference\\\":\\\"Psalm 23:1\\\",\\\"theme\\\":\\\"abiding_presence\\\",\\\"theme_display_name\\\":\\\"Abiding Presence\\\",\\\"rationale\\\":\\\"The Lord is my shepherd.\\\",\\\"alternates\\\":[]}\\n```"
                let completionJSON = """
                {"choices":[{"message":{"role":"assistant","content":"\(fencedContent)"}}]}
                """.data(using: .utf8)!
                return (makeHTTPResponse(url: anyURL, status: 200), completionJSON)
            }
        }

        let client = GlooAIClient(clientID: "id", clientSecret: "secret", session: stubbedSession())
        let context = VerseSelectionContext(
            state: .peacefulSteady,
            timeOfDay: .morning,
            confidence: 0.9
        )
        let selection = try await client.selectVerse(for: context)
        XCTAssertEqual(selection.reference, "Psalm 23:1")
    }

    // MARK: - Private Helpers

    private static func jsonString(_ s: String) -> String {
        // Wrap string in quotes, escaping internal quotes
        let escaped = s.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
