import Foundation

// MARK: - Gloo AI Client
//
// Auth: OAuth2 Client Credentials
//   Token endpoint: POST https://platform.ai.gloo.com/oauth2/token
//   Body: grant_type=client_credentials&scope=api/access (URL-encoded)
//   Auth method: HTTP Basic (CLIENT_ID:CLIENT_SECRET)
//   Response: {"access_token":"eyJ...","token_type":"Bearer","expires_in":3600}
//   Token cached until expiry minus 60 seconds.
//
// Chat completions: POST https://platform.ai.gloo.com/ai/v2/chat/completions
//   Headers: Authorization: Bearer <token>, Content-Type: application/json
//   Body: {"messages":[...],"model":"gloo-anthropic-claude-sonnet-4.6","tradition":"evangelical"}
//   Response: {"choices":[{"message":{"content":"<model output>"}}]}
//   Model output: JSON object with verse_reference, theme, theme_display_name, rationale, alternates
//   No JSON mode — parse defensively; strip markdown fences; find first { to last }.
//
// Privacy constraint: user message contains ONLY state raw value, state display name,
// time of day, confidence, recent state raw values, translation abbreviation,
// preferred themes, avoid-repeats references. NO raw health numbers.

// MARK: - Internal Models

private struct GlooTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct GlooUserMessage: Encodable {
    let state: String
    let stateDisplayName: String
    let timeOfDay: String
    let confidence: Double
    let recentStates: [String]
    let translationAbbreviation: String
    let preferredThemes: [String]
    let avoidRepeats: [String]

    enum CodingKeys: String, CodingKey {
        case state
        case stateDisplayName = "state_display_name"
        case timeOfDay = "time_of_day"
        case confidence
        case recentStates = "recent_states"
        case translationAbbreviation = "translation_abbreviation"
        case preferredThemes = "preferred_themes"
        case avoidRepeats = "avoid_repeats"
    }
}

private struct GlooChatRequest: Encodable {
    let messages: [GlooMessage]
    let model: String
    let tradition: String
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case messages
        case model
        case tradition
        case maxTokens = "max_tokens"
    }
}

private struct GlooMessage: Encodable {
    let role: String
    let content: String
}

private struct GlooChatResponse: Decodable {
    let choices: [GlooChoice]
}

private struct GlooChoice: Decodable {
    let message: GlooMessageContent
}

private struct GlooMessageContent: Decodable {
    let content: String
}

/// The JSON structure we ask the model to return.
private struct ModelVerseJSON: Decodable {
    let verseReference: String
    let theme: String
    let themeDisplayName: String
    let rationale: String?
    let alternates: [String]

    enum CodingKeys: String, CodingKey {
        case verseReference = "verse_reference"
        case theme
        case themeDisplayName = "theme_display_name"
        case rationale
        case alternates
    }
}

// MARK: - Cached Token

private struct CachedToken {
    let value: String
    let expiresAt: Date
}

// MARK: - GlooAIClient

/// OAuth2 client-credentials client for the Gloo AI Platform.
///
/// Automatically fetches and caches the Bearer token, refreshing 60 seconds
/// before expiry. Constructs a privacy-safe user message (no raw health numbers)
/// and parses the model's JSON output defensively.
public actor GlooAIClient: VerseSelecting {

    private let clientID: String
    private let clientSecret: String
    private let session: URLSession

    private var cachedToken: CachedToken?

    private static let tokenURL = URL(string: "https://platform.ai.gloo.com/oauth2/token")!
    private static let completionsURL = URL(string: "https://platform.ai.gloo.com/ai/v2/chat/completions")!
    private static let model = "gloo-anthropic-claude-sonnet-4.6"

    // System prompt from Instructions/04_AI_SCRIPTURE_ENGINE.md lines 141-158,
    // plus added instruction for JSON-only output with required keys.
    private static let systemPrompt = """
You are a pastoral scripture guide for a health and wellness app called Pulse. \
Your role is to select a single Bible verse (or short passage of 2–3 verses) that is \
most relevant and meaningful to a person currently experiencing the described physical \
and emotional state.

Guidelines:
- Select verses that DIRECTLY address the stated condition
- Prefer well-known, beloved verses that resonate emotionally
- Never select verses that could feel judgmental or shame-inducing
- For physical states (post-workout, sick), select verses that honor the body as God's temple
- For emotional states (stressed, sad), select verses that offer genuine comfort
- Vary selections over time — do not repeat verses frequently
- Consider the time of day (morning verses are energizing; evening verses are peaceful)
- The translation is a preference — always select the reference, not translation-specific text

Return JSON only. No explanation outside the JSON structure. Return ONLY a JSON object \
with exactly these keys: verse_reference (string), theme (string, snake_case), \
theme_display_name (string), rationale (string), alternates (array of strings).
"""

    public init(clientID: String, clientSecret: String, session: URLSession = .shared) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.session = session
    }

    // MARK: - VerseSelecting

    public func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection {
        let token = try await validToken()
        let modelJSON = try await requestCompletion(token: token, context: context)
        return VerseSelection(
            reference: modelJSON.verseReference,
            theme: modelJSON.theme,
            themeDisplayName: modelJSON.themeDisplayName,
            rationale: modelJSON.rationale,
            alternates: modelJSON.alternates,
            isFallback: false
        )
    }

    // MARK: - Token Management

    private func validToken() async throws -> String {
        let now = Date()
        if let cached = cachedToken, cached.expiresAt > now {
            return cached.value
        }
        let token = try await fetchToken()
        cachedToken = token
        return token.value
    }

    private func fetchToken() async throws -> CachedToken {
        var request = URLRequest(url: Self.tokenURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Basic auth: base64(clientID:clientSecret)
        let credentials = "\(clientID):\(clientSecret)"
        guard let credData = credentials.data(using: .utf8) else {
            throw ScriptureAPIError.notConfigured
        }
        let encoded = credData.base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        request.httpBody = "grant_type=client_credentials&scope=api/access".data(using: .utf8)

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw ScriptureAPIError.authFailed
            }
            throw ScriptureAPIError.requestFailed(status: http.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(GlooTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(Double(tokenResponse.expiresIn) - 60)
        return CachedToken(value: tokenResponse.accessToken, expiresAt: expiresAt)
    }

    // MARK: - Chat Completions

    private func requestCompletion(token: String, context: VerseSelectionContext) async throws -> ModelVerseJSON {
        let userMsg = GlooUserMessage(
            state: context.state.rawValue,
            stateDisplayName: context.state.displayName,
            timeOfDay: context.timeOfDay.rawValue,
            confidence: context.confidence,
            recentStates: context.recentStates.map(\.rawValue),
            translationAbbreviation: context.translation.abbreviation,
            preferredThemes: context.preferredThemes,
            avoidRepeats: context.avoidRepeats
        )

        let encoder = JSONEncoder()
        guard let userMsgData = try? encoder.encode(userMsg),
              let userMsgString = String(data: userMsgData, encoding: .utf8) else {
            throw ScriptureAPIError.decodingFailed
        }

        let chatRequest = GlooChatRequest(
            messages: [
                GlooMessage(role: "system", content: Self.systemPrompt),
                GlooMessage(role: "user", content: userMsgString)
            ],
            model: Self.model,
            tradition: "evangelical",
            maxTokens: 512
        )

        var request = URLRequest(url: Self.completionsURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(chatRequest)

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw ScriptureAPIError.requestFailed(status: 0)
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw ScriptureAPIError.authFailed
            }
            throw ScriptureAPIError.requestFailed(status: http.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(GlooChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw ScriptureAPIError.decodingFailed
        }

        return try parseModelJSON(content)
    }

    // MARK: - Defensive JSON Parsing

    /// Strips markdown code fences, finds first { to last }, decodes as ModelVerseJSON.
    private func parseModelJSON(_ raw: String) throws -> ModelVerseJSON {
        // Strip markdown code fences (```json ... ``` or ``` ... ```)
        var text = raw
        if let fenceStart = text.range(of: "```") {
            // skip the opening fence line
            if let newline = text.range(of: "\n", range: fenceStart.upperBound..<text.endIndex) {
                text = String(text[newline.upperBound...])
            }
        }
        if let closingFence = text.range(of: "```") {
            text = String(text[..<closingFence.lowerBound])
        }

        // Find first { to last }
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            throw ScriptureAPIError.decodingFailed
        }
        guard firstBrace <= lastBrace else {
            throw ScriptureAPIError.decodingFailed
        }
        let jsonSubstring = String(text[firstBrace...lastBrace])

        guard let jsonData = jsonSubstring.data(using: .utf8) else {
            throw ScriptureAPIError.decodingFailed
        }

        do {
            return try JSONDecoder().decode(ModelVerseJSON.self, from: jsonData)
        } catch {
            throw ScriptureAPIError.decodingFailed
        }
    }

    // MARK: - Network Helper

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
}
