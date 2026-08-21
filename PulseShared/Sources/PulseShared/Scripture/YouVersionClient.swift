import Foundation

// MARK: - YouVersion Client
//
// Auth: Static App Key in X-YVP-App-Key header (no token exchange needed)
//
// Bible passage: GET https://api.youversion.com/v1/bibles/{bibleId}/passages/{usfmRef}?format=text
//   Response: {"id":"MAT.11.28","content":"Come to Me...","reference":"Matthew 11:28"}
//   No copyright field in passage response (verified 2026-07-31 with BSB 3034).
//
// Bible listing: GET https://api.youversion.com/v1/bibles?language_ranges[]=eng
//   language_ranges[]=eng is REQUIRED; omitting causes HTTP 422.
//   Returns only granted bibles (11 for this App Key, including BSB 3034).
//   Response items: {"id":"3034","abbreviation":"BSB","name":"Berean Standard Bible"}
//
// Access denied response: {"message":"Access denied for <id>"} (non-2xx or this body)
// HTTP 401/403 → .authFailed; other non-2xx → .requestFailed(status:)
//
// USFM range format (same chapter): MAT.11.28-30 (book prefix omitted on end).
// This is the format verified by the live API and confirmed in api-contracts.md.

// MARK: - Internal Decodable Types

private struct YouVersionPassageResponse: Decodable {
    let id: String
    let reference: String
    let content: String
}

private struct VOTDResponse: Decodable {
    let day: Int
    let passageId: String

    enum CodingKeys: String, CodingKey {
        case day
        case passageId = "passage_id"
    }
}

private struct YouVersionBiblesResponse: Decodable {
    let data: [YouVersionBibleItem]
}

private struct YouVersionBibleItem: Decodable {
    let id: String
    let abbreviation: String
    // Accept "name", "title", or "local_title" — all in one decoder
    let name: String?
    let title: String?
    let localTitle: String?

    enum CodingKeys: String, CodingKey {
        case id, abbreviation, name, title
        case localTitle = "local_title"
    }

    var resolvedTitle: String {
        name ?? title ?? localTitle ?? abbreviation
    }
}

// MARK: - YouVersionClient

/// App-Key authenticated client for the YouVersion Platform API.
///
/// Fetches Bible passage text using numeric bible IDs and USFM references.
/// Supports listing granted bibles (GET /v1/bibles?language_ranges[]=eng).
/// Default bible: BSB (id 3034), confirmed available for this App Key.
public struct YouVersionClient: VerseFetching {

    private let appKey: String
    private let session: URLSession
    private let maxAttempts: Int
    private let retryBaseDelay: Double

    private static let baseURL = URL(string: "https://api.youversion.com")!
    private static let appKeyHeader = "X-YVP-App-Key"

    /// - Parameters:
    ///   - maxAttempts: Total attempts for a passage fetch, including the first (default 3).
    ///     Transient failures (timeouts, dropped connections, 429/5xx) are retried with
    ///     exponential backoff so a momentary hiccup doesn't surface as an offline fallback.
    ///   - retryBaseDelay: Base backoff in seconds; attempt N waits `retryBaseDelay * 2^N`.
    ///     Tests pass 0 to avoid real sleeps.
    public init(
        appKey: String,
        session: URLSession = .shared,
        maxAttempts: Int = 3,
        retryBaseDelay: Double = 0.4
    ) {
        self.appKey = appKey
        self.session = session
        self.maxAttempts = max(1, maxAttempts)
        self.retryBaseDelay = max(0, retryBaseDelay)
    }

    // MARK: - VerseFetching

    /// Fetches verse text from YouVersion using a numeric bible ID.
    ///
    /// - Parameters:
    ///   - reference: Human-readable reference like "Matthew 11:28" or "Matthew 11:28-30"
    ///   - bibleID: Numeric YouVersion bible version ID (e.g. 3034 for BSB)
    ///   - abbreviation: Translation abbreviation (e.g. "BSB") — passed through to BibleVerse
    ///     since the passage response does not include the translation abbreviation.
    public func fetchVerse(reference: String, bibleID: Int, abbreviation: String) async throws -> BibleVerse {
        guard let usfm = USFM.usfm(for: reference) else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }
        return try await fetchPassage(passageID: usfm, bibleID: bibleID, abbreviation: abbreviation)
    }

    /// Fetches the verse of the day for a given day-of-year.
    ///
    /// - Parameters:
    ///   - bibleID: Numeric YouVersion bible version ID (e.g. 3034 for BSB)
    ///   - abbreviation: Translation abbreviation (e.g. "BSB") — passed through to BibleVerse
    ///   - day: Day-of-year (1–366). Defaults to the current day of year.
    public func fetchVerseOfTheDay(bibleID: Int, abbreviation: String, day: Int? = nil) async throws -> BibleVerse {
        let dayOfYear = day ?? Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1

        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v1/verse_of_the_days/\(dayOfYear)"

        guard let url = components.url else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(appKey, forHTTPHeaderField: Self.appKeyHeader)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (votdData, votdResponse) = try await performRequest(request)
        try checkResponse(data: votdData, response: votdResponse)

        let votd = try decode(VOTDResponse.self, from: votdData)
        return try await fetchPassage(passageID: votd.passageId, bibleID: bibleID, abbreviation: abbreviation)
    }

    // MARK: - Shared Passage Fetch

    /// Fetches a passage by USFM passage ID and wraps it into a BibleVerse.
    /// Used by both `fetchVerse` and `fetchVerseOfTheDay`.
    private func fetchPassage(passageID: String, bibleID: Int, abbreviation: String) async throws -> BibleVerse {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v1/bibles/\(bibleID)/passages/\(passageID)"
        components.queryItems = [URLQueryItem(name: "format", value: "text")]

        guard let url = components.url else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(appKey, forHTTPHeaderField: Self.appKeyHeader)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await performWithRetry(request)

        let passage = try decode(YouVersionPassageResponse.self, from: data)

        // Build chapter URL: https://www.bible.com/bible/{bibleId}/{BOOK.C}
        let chapterURLString = buildChapterURL(usfm: passageID, bibleID: bibleID)

        return BibleVerse(
            id: passage.id,
            reference: passage.reference,
            text: passage.content,
            translationAbbreviation: abbreviation,
            copyright: attributionString(for: bibleID, abbreviation: abbreviation),
            chapterURLString: chapterURLString
        )
    }

    // MARK: - Bible Listing

    /// Lists Bible versions granted for this App Key.
    /// Calls GET /v1/bibles?language_ranges[]=eng.
    public func listBibles() async throws -> [BibleVersion] {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v1/bibles"
        // language_ranges[] bracket syntax must be preserved verbatim (HTTP 422 without it)
        components.percentEncodedQuery = "language_ranges%5B%5D=eng"

        guard let url = components.url else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(appKey, forHTTPHeaderField: Self.appKeyHeader)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        try checkResponse(data: data, response: response)

        // Try wrapped {"data":[...]} first, then bare array
        let items: [YouVersionBibleItem]
        if let wrapped = try? JSONDecoder().decode(YouVersionBiblesResponse.self, from: data) {
            items = wrapped.data
        } else if let bare = try? JSONDecoder().decode([YouVersionBibleItem].self, from: data) {
            items = bare
        } else {
            throw ScriptureAPIError.decodingFailed
        }

        return items.compactMap { item in
            guard let numericID = Int(item.id) else { return nil }
            return BibleVersion(id: numericID, abbreviation: item.abbreviation, title: item.resolvedTitle)
        }
    }

    // MARK: - Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw ScriptureAPIError.timedOut
            }
            throw urlError
        }
    }

    /// Performs the request and validates the response, retrying transient failures
    /// (timeouts, dropped connections, 429/5xx) up to `maxAttempts` with exponential
    /// backoff. Non-transient errors (auth, 4xx, decode) fail fast without retrying.
    private func performWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error = ScriptureAPIError.requestFailed(status: 0)
        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await performRequest(request)
                try checkResponse(data: data, response: response)
                return (data, response)
            } catch let error where Self.isRetriable(error) {
                lastError = error
                let isLastAttempt = attempt == maxAttempts - 1
                if isLastAttempt { break }
                if retryBaseDelay > 0 {
                    let seconds = retryBaseDelay * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }
            }
        }
        throw lastError
    }

    /// Transient errors worth retrying. Auth failures, 4xx (other than 429), and
    /// decode errors are permanent and must fail fast.
    private static func isRetriable(_ error: Error) -> Bool {
        if let apiError = error as? ScriptureAPIError {
            switch apiError {
            case .timedOut:
                return true
            case .requestFailed(let status):
                return status == 0 || status == 429 || (500...599).contains(status)
            case .authFailed, .decodingFailed, .notConfigured:
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet,
                 .resourceUnavailable, .badServerResponse:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func checkResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }

        // Check for "Access denied" body (may come with 200 or non-2xx)
        if let body = String(data: data, encoding: .utf8), body.contains("Access denied") {
            throw ScriptureAPIError.authFailed
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw ScriptureAPIError.authFailed
            }
            throw ScriptureAPIError.requestFailed(status: http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ScriptureAPIError.decodingFailed
        }
    }

    /// Build a bible.com chapter URL from a USFM reference.
    /// e.g. MAT.11.28 → https://www.bible.com/bible/3034/MAT.11
    private func buildChapterURL(usfm: String, bibleID: Int) -> String? {
        // Extract BOOK.CHAPTER from USFM (e.g. "MAT.11.28" → "MAT.11", "MAT.11.28-30" → "MAT.11")
        let parts = usfm.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let bookChapter = "\(parts[0]).\(parts[1])"
        return "https://www.bible.com/bible/\(bibleID)/\(bookChapter)"
    }

    /// Static copyright/attribution string per translation.
    /// The YouVersion passage endpoint does not include a copyright field.
    private func attributionString(for bibleID: Int, abbreviation: String) -> String {
        switch bibleID {
        case 3034: return "Berean Standard Bible © 2016, 2018 Bible Hub"
        case 12:   return "American Standard Version (Public Domain)"
        case 206:  return "World English Bible (Public Domain)"
        case 2660: return "Literal Standard Version © 2020 Covenant Press"
        default:   return "\(abbreviation) — see YouVersion for copyright details"
        }
    }
}
