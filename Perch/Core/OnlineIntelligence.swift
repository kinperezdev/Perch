import Foundation

/// Optional cloud models, used only when the user turns on Online mode and
enum OnlineIntelligence {

    enum Provider: Equatable {
        case openAI(key: String)
        case gemini(key: String)
        case anthropic(key: String)

        var label: String {
            switch self {
            case .openAI: "OpenAI"
            case .gemini: "Gemini"
            case .anthropic: "Claude"
            }
        }
    }

    /// First provider the user has configured, preferring OpenAI, then Gemini, then Claude.
    @MainActor
    static func firstConfigured(prefs: PreferencesStore) -> Provider? {
        let openAI = prefs.openAiApiKey.trimmingCharacters(in: .whitespaces)
        let gemini = prefs.geminiApiKey.trimmingCharacters(in: .whitespaces)
        let anthropic = prefs.anthropicApiKey.trimmingCharacters(in: .whitespaces)
        if !openAI.isEmpty { return .openAI(key: openAI) }
        if !gemini.isEmpty { return .gemini(key: gemini) }
        if !anthropic.isEmpty { return .anthropic(key: anthropic) }
        return nil
    }

    static func generate(provider: Provider, system: String, prompt: String) async -> String? {
        switch provider {
        case .openAI(let key): await openAI(key: key, system: system, prompt: prompt)
        case .gemini(let key): await gemini(key: key, system: system, prompt: prompt)
        case .anthropic(let key): await anthropic(key: key, system: system, prompt: prompt)
        }
    }

    // MARK: OpenAI

    private static func openAI(key: String, system: String, prompt: String) async -> String? {
        struct Body: Encodable {
            struct Message: Encodable { let role: String; let content: String }
            let model: String
            let messages: [Message]
            let temperature: Double
            let max_tokens: Int
        }
        struct Reply: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        let body = Body(
            model: "gpt-4o-mini",
            messages: [.init(role: "system", content: system), .init(role: "user", content: prompt)],
            temperature: 0.8,
            max_tokens: 220
        )
        let reply: Reply? = await post(
            "https://api.openai.com/v1/chat/completions",
            headers: ["Authorization": "Bearer \(key)"],
            body: body
        )
        return reply?.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Gemini

    private static func gemini(key: String, system: String, prompt: String) async -> String? {
        struct Body: Encodable {
            struct Part: Encodable { let text: String }
            struct Content: Encodable { let parts: [Part] }
            struct SystemInstruction: Encodable { let parts: [Part] }
            let contents: [Content]
            let systemInstruction: SystemInstruction
        }
        struct Reply: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable { struct Part: Decodable { let text: String }; let parts: [Part] }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let body = Body(
            contents: [.init(parts: [.init(text: prompt)])],
            systemInstruction: .init(parts: [.init(text: system)])
        )
        let url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(key)"
        let reply: Reply? = await post(url, headers: [:], body: body)
        return reply?.candidates.first?.content.parts.first?.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Anthropic

    private static func anthropic(key: String, system: String, prompt: String) async -> String? {
        struct Body: Encodable {
            struct Message: Encodable { let role: String; let content: String }
            let model: String
            let max_tokens: Int
            let system: String
            let messages: [Message]
        }
        struct Reply: Decodable {
            struct Block: Decodable { let text: String? }
            let content: [Block]
        }
        let body = Body(
            model: "claude-3-5-haiku-latest",
            max_tokens: 220,
            system: system,
            messages: [.init(role: "user", content: prompt)]
        )
        let reply: Reply? = await post(
            "https://api.anthropic.com/v1/messages",
            headers: ["x-api-key": key, "anthropic-version": "2023-06-01"],
            body: body
        )
        return reply?.content.compactMap(\.text).first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Transport

    private static func post<B: Encodable, R: Decodable>(
        _ urlString: String,
        headers: [String: String],
        body: B
    ) async -> R? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        request.httpBody = try? JSONEncoder().encode(body)
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { return nil }
        return try? JSONDecoder().decode(R.self, from: data)
    }
}
