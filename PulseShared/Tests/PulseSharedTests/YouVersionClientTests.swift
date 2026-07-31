import XCTest
@testable import PulseShared

final class YouVersionClientTests: XCTestCase {

    // MARK: - Happy Path

    func testFetchVerseParsesResponse() async throws {
        // Verified live response shape for BSB 3034 Matthew 11:28 with ?format=text
        // {"id":"MAT.11.28","content":"Come to Me, all you who are weary...","reference":"Matthew 11:28"}
        // No copyright field in passage response (verified 2026-07-31).

        StubURLProtocol.requestHandler = { request in
            let anyURL = URL(string: "https://example.com")!
            // Verify X-YVP-App-Key header is set
            XCTAssertNotNil(request.value(forHTTPHeaderField: "X-YVP-App-Key"))
            // Verify USFM path and format=text param
            XCTAssertTrue(request.url?.path.contains("MAT.11.28") == true, "URL must include USFM reference")
            XCTAssertTrue(request.url?.query?.contains("format=text") == true, "URL must request plain text")

            let responseJSON = """
            {
              "id": "MAT.11.28",
              "content": "Come to Me, all you who are weary and burdened, and I will give you rest.",
              "reference": "Matthew 11:28"
            }
            """.data(using: .utf8)!
            return (makeHTTPResponse(url: anyURL, status: 200), responseJSON)
        }

        let client = YouVersionClient(appKey: "test-key", session: stubbedSession())
        let verse = try await client.fetchVerse(reference: "Matthew 11:28", bibleID: 3034, abbreviation: "BSB")

        XCTAssertEqual(verse.reference, "Matthew 11:28")
        XCTAssertEqual(verse.id, "MAT.11.28")
        XCTAssertTrue(verse.text.contains("weary"), "Text should contain passage content")
        XCTAssertEqual(verse.translationAbbreviation, "BSB")
    }

    func testFetchVerseRangeParsesResponse() async throws {
        // Range: Matthew 11:28-30 → USFM MAT.11.28-30 (short range, chapter prefix omitted on end)

        StubURLProtocol.requestHandler = { request in
            let anyURL = URL(string: "https://example.com")!
            XCTAssertTrue(request.url?.path.contains("MAT.11.28-30") == true, "URL must use short range USFM")

            let responseJSON = """
            {
              "id": "MAT.11.28-30",
              "content": "Come to Me, all you who are weary and burdened, and I will give you rest. Take My yoke upon you and learn from Me, for I am gentle and humble in heart, and you will find rest for your souls. For My yoke is easy and My burden is light.",
              "reference": "Matthew 11:28-30"
            }
            """.data(using: .utf8)!
            return (makeHTTPResponse(url: anyURL, status: 200), responseJSON)
        }

        let client = YouVersionClient(appKey: "test-key", session: stubbedSession())
        let verse = try await client.fetchVerse(reference: "Matthew 11:28-30", bibleID: 3034, abbreviation: "BSB")

        XCTAssertEqual(verse.id, "MAT.11.28-30")
        XCTAssertEqual(verse.reference, "Matthew 11:28-30")
        XCTAssertTrue(verse.text.contains("yoke"), "Range text should be present")
    }

    // MARK: - USFM Conversion

    func testUSFMConversion() {
        XCTAssertEqual(USFM.usfm(for: "Matthew 11:28"), "MAT.11.28")
        XCTAssertEqual(USFM.usfm(for: "Psalm 34:18"), "PSA.34.18")
        XCTAssertEqual(USFM.usfm(for: "1 John 4:19"), "1JN.4.19")
        // Short range: chapter prefix omitted on end (MAT.11.28-30 not MAT.11.28-MAT.11.30)
        XCTAssertEqual(USFM.usfm(for: "Matthew 11:28-30"), "MAT.11.28-30")
        XCTAssertNil(USFM.usfm(for: "Bogus 99:99"))
    }

    func testUSFMAdditionalBooks() {
        XCTAssertEqual(USFM.usfm(for: "Genesis 1:1"), "GEN.1.1")
        XCTAssertEqual(USFM.usfm(for: "John 3:16"), "JHN.3.16")
        XCTAssertEqual(USFM.usfm(for: "Revelation 21:4"), "REV.21.4")
        XCTAssertEqual(USFM.usfm(for: "1 Corinthians 13:4"), "1CO.13.4")
        XCTAssertEqual(USFM.usfm(for: "Philippians 4:13"), "PHP.4.13")
        XCTAssertEqual(USFM.usfm(for: "Romans 8:28"), "ROM.8.28")
        XCTAssertEqual(USFM.usfm(for: "Isaiah 40:31"), "ISA.40.31")
    }

    // MARK: - Auth Failure

    func testAuthFailureThrows() async {
        StubURLProtocol.requestHandler = { request in
            let anyURL = URL(string: "https://example.com")!
            return (makeHTTPResponse(url: anyURL, status: 401), Data())
        }

        let client = YouVersionClient(appKey: "bad-key", session: stubbedSession())
        do {
            _ = try await client.fetchVerse(reference: "Matthew 11:28", bibleID: 3034, abbreviation: "BSB")
            XCTFail("Expected authFailed")
        } catch ScriptureAPIError.authFailed {
            // Expected
        } catch {
            XCTFail("Expected .authFailed, got \(error)")
        }
    }

    func testAccessDeniedBodyThrowsAuthFailed() async {
        // Verified: commercial translations return {"message":"Access denied for 111"}
        StubURLProtocol.requestHandler = { request in
            let anyURL = URL(string: "https://example.com")!
            let body = """
            {"message":"Access denied for 111"}
            """.data(using: .utf8)!
            // Status may be 200 or 403 — our code checks body too
            return (makeHTTPResponse(url: anyURL, status: 403), body)
        }

        let client = YouVersionClient(appKey: "key", session: stubbedSession())
        do {
            _ = try await client.fetchVerse(reference: "John 3:16", bibleID: 111, abbreviation: "NIV")
            XCTFail("Expected authFailed")
        } catch ScriptureAPIError.authFailed {
            // Expected
        } catch {
            XCTFail("Expected .authFailed, got \(error)")
        }
    }

    // MARK: - List Bibles (wrapped response)

    func testListBiblesDecodesWrappedResponse() async throws {
        StubURLProtocol.requestHandler = { request in
            let anyURL = URL(string: "https://example.com")!
            XCTAssertTrue(request.url?.query?.contains("language_ranges") == true, "language_ranges[] required")

            let responseJSON = """
            {
              "data": [
                {"id": "3034", "abbreviation": "BSB", "name": "Berean Standard Bible"},
                {"id": "206",  "abbreviation": "WEB", "name": "World English Bible"}
              ]
            }
            """.data(using: .utf8)!
            return (makeHTTPResponse(url: anyURL, status: 200), responseJSON)
        }

        let client = YouVersionClient(appKey: "test-key", session: stubbedSession())
        let bibles = try await client.listBibles()

        XCTAssertEqual(bibles.count, 2)
        let bsb = bibles.first { $0.id == 3034 }
        XCTAssertNotNil(bsb)
        XCTAssertEqual(bsb?.abbreviation, "BSB")
        XCTAssertEqual(bsb?.title, "Berean Standard Bible")
    }

    // MARK: - Default Bible Constants

    func testDefaultBibleConstants() {
        XCTAssertEqual(DefaultBible.id, 3034)
        XCTAssertEqual(DefaultBible.abbreviation, "BSB")
        XCTAssertFalse(DefaultBible.title.isEmpty)
    }
}
