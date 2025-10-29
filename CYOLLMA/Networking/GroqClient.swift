import Foundation

enum GroqClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case missingContent
    case modelOutputMalformed
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Groq URL"
        case .invalidResponse: return "Unexpected Groq response"
        case .decodingFailed: return "Failed to decode Groq response"
        case .missingContent: return "Groq response missing content"
        case .modelOutputMalformed: return "Groq returned unexpected output"
        case .serverError(let message): return message
        }
    }
}

struct GroqClient {
    struct TurnPayload: Decodable {
        let narrative: String
        let summary: String
        let options: [ChoiceOption]
    }

    struct ChoicesPayload: Decodable {
        let options: [ChoiceOption]
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let max_completion_tokens: Int
        let top_p: Double
        let stream: Bool
        let reasoning_effort: String?
        let response_format: ResponseFormat?
        let stop: [String]?

        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }

    private let baseURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let speechURL = URL(string: "https://api.groq.com/openai/v1/audio/speech")!

    static let supportedModels: [String] = [
        "openai/gpt-oss-120b",
        "llama-3.1-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768"
    ]

    private struct SpeechRequest: Encodable {
        let model: String
        let voice: String
        let input: String
        let response_format: String
    }

    func generateTurn(model: String, temperature: Double, context: String, apiKey: String) async throws -> TurnPayload {
        let prompt = buildNarrativePrompt(with: context)
        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: narrativeSystemPrompt),
                .init(role: "user", content: prompt)
            ],
            temperature: temperature,
            max_completion_tokens: 8192,
            top_p: 1,
            stream: false,
            reasoning_effort: "medium",
            response_format: .init(type: "json_object"),
            stop: nil
        )

        let response = try await performRequest(body: body, apiKey: apiKey)
        guard let raw = response.choices.first?.message.content else { throw GroqClientError.missingContent }

        guard let data = raw.data(using: .utf8) else { throw GroqClientError.decodingFailed }
        do {
            return try JSONDecoder().decode(TurnPayload.self, from: data)
        } catch {
            throw GroqClientError.modelOutputMalformed
        }
    }

    func synthesizeSpeech(text: String, voice: String, apiKey: String) async throws -> Data {
        var request = URLRequest(url: speechURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = SpeechRequest(
            model: "playai-tts",
            voice: voice,
            input: text,
            response_format: "wav"
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GroqClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).error {
                throw GroqClientError.serverError(message)
            }
            throw GroqClientError.invalidResponse
        }
        return data
    }

    func generateChoices(model: String, temperature: Double, context: String, apiKey: String) async throws -> [ChoiceOption] {
        let prompt = buildChoicesPrompt(with: context)
        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: choicesSystemPrompt),
                .init(role: "user", content: prompt)
            ],
            temperature: temperature,
            max_completion_tokens: 2048,
            top_p: 1,
            stream: false,
            reasoning_effort: "medium",
            response_format: .init(type: "json_object"),
            stop: nil
        )

        let response = try await performRequest(body: body, apiKey: apiKey)
        guard let raw = response.choices.first?.message.content else { throw GroqClientError.missingContent }

        guard let data = raw.data(using: .utf8) else { throw GroqClientError.decodingFailed }
        do {
            let payload = try JSONDecoder().decode(ChoicesPayload.self, from: data)
            return payload.options
        } catch {
            throw GroqClientError.modelOutputMalformed
        }
    }

    private func performRequest(body: ChatRequest, apiKey: String) async throws -> ChatResponse {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GroqClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).error {
                throw GroqClientError.serverError(message)
            }
            throw GroqClientError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw GroqClientError.decodingFailed
        }
    }

    private func buildNarrativePrompt(with context: String) -> String {
        """
        Context:
        \(context)

        Task: Continue the story with the system directives above. Respond with STRICT JSON containing fields narrative (string), summary (string), options (array of {id:string,label:string}).
        """
    }

    private func buildChoicesPrompt(with context: String) -> String {
        """
        Context:
        \(context)

        Task: Produce only the refreshed actionable options. Respond with STRICT JSON containing field options (array of {id:string,label:string}).
        """
    }

    private var narrativeSystemPrompt: String {
        """
        You are a Choose-Your-Own-Adventure engine.
        Return STRICT JSON with fields: narrative (string), summary (string), options (array of {id:string,label:string}).
        Do not include markdown, code fences, bullet points, or commentary. Output JSON only.

        Narrative guidelines:
        - Aim for roughly 180-220 words.
        - Blend rich exposition with dialogue (roughly 60% narration, 40% dialogue).
        - Whenever characters speak, format each speaker on its own line using: Character Name: "Dialogue here."
        - Leave a blank line between paragraphs for readability.
        - Keep tone consonant with the context while moving the story forward.
        - Advance the plot; do not repeat or lightly paraphrase sentences from earlier chapters.
        - If you must mention prior events, summarize them in a single fresh sentence before moving on.
        - Begin exactly where the previous passage ended, acknowledging the latest player decision as already underway.

        Summary guidelines:
        - Provide a single sentence (max 32 words) capturing the new developments from this chapter only.
        - Use fresh wording distinct from previous summaries and chapters.
        - Focus on concrete actions, discoveries, or shifts in stakes; avoid flowery recap language.

        Choice guidelines:
        - Provide 3-4 concise options.
        - Options must be actionable impulses phrased as first-person intentions (e.g., "Step onto the lit bridge").
        """
    }

    private var choicesSystemPrompt: String {
        """
        You are a narrative design assistant refreshing player choices for an in-progress interactive fiction story.
        Return STRICT JSON with field: options (array of {id:string,label:string}).
        Do not return narrative, markdown, or commentary—only JSON.

        Choice guidelines:
        - Provide 3-4 distinct options.
        - Write each as a first-person immediate action the protagonist might take next.
        - Keep each option under 18 words.
        - Reflect the current scene details, tone, and stakes provided in the context.
        - Ensure options diverge meaningfully; avoid near-duplicates or mutually exclusive contradictions.
        """
    }
}
