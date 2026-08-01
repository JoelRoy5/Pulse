import XCTest
@testable import PulseShared

final class VerseOfTheDayTests: XCTestCase {
    func testFetchVOTDTwoStep() async throws {
        StubURLProtocol.requestHandler = { req in
            let url = req.url!.absoluteString
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.contains("/verse_of_the_days/") {
                return (resp, Data(#"{"day":15,"passage_id":"JHN.3.16"}"#.utf8))
            } else {  // passage fetch
                return (resp, Data(#"{"id":"JHN.3.16","content":"For God so loved the world...","reference":"John 3:16"}"#.utf8))
            }
        }
        let client = YouVersionClient(appKey: "k", session: stubbedSession())
        let verse = try await client.fetchVerseOfTheDay(bibleID: 3034, abbreviation: "BSB", day: 15)
        XCTAssertEqual(verse.reference, "John 3:16")
        XCTAssertEqual(verse.translationAbbreviation, "BSB")
        XCTAssertFalse(verse.text.isEmpty)
    }
    func testVOTDAuthFailure() async {
        StubURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = YouVersionClient(appKey: "k", session: stubbedSession())
        do { _ = try await client.fetchVerseOfTheDay(bibleID: 3034, abbreviation: "BSB", day: 15)
             XCTFail("expected throw")
        } catch let e as ScriptureAPIError { XCTAssertEqual(e, .authFailed) }
        catch { XCTFail("wrong error \(error)") }
    }
}
