import Foundation

enum OllamaClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case modelOutputMalformed
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama URL"
        case .invalidResponse: return "Unexpected server response"
        case .decodingFailed: return "Failed to decode response"
        case .modelOutputMalformed: return "Model returned unexpected output"
        case .serverError(let message): return message
        }
    }
}

struct OllamaClient {
    struct RequestBody: Encodable {
        let model: String
        let prompt: String
        let format: String = "json"
        let stream: Bool = false
        let options: Options

        struct Options: Encodable { let temperature: Double }
    }

    private struct RawResponse: Decodable {
        let response: String
    }

    struct TurnPayload: Decodable {
        let narrative: String
        let summary: String
        let options: [ChoiceOption]
    }

    struct ChoicesPayload: Decodable {
        let options: [ChoiceOption]
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }

    private struct TagsResponse: Decodable {
        struct Tag: Decodable { let name: String }
        let models: [Tag]
    }

    var baseURL: URL = URL(string: "http://127.0.0.1:11434")!

    func generateTurn(model: String, temperature: Double, context: String) async throws -> TurnPayload {
        guard let url = URL(string: "/api/generate", relativeTo: baseURL) else { throw OllamaClientError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let preamble = """
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
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let prompt = "\(preamble)\n\nContext:\n\(context)\n\nTask: Continue the story with those constraints."

        let body = RequestBody(model: model, prompt: prompt, options: .init(temperature: temperature))
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaClientError.invalidResponse }
        guard http.statusCode == 200 else {
            if let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).error {
                throw OllamaClientError.serverError(message)
            }
            throw OllamaClientError.invalidResponse
        }

        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        guard let innerData = raw.response.data(using: .utf8) else { throw OllamaClientError.decodingFailed }

        do {
            let payload = try JSONDecoder().decode(TurnPayload.self, from: innerData)
            return payload
        } catch {
            throw OllamaClientError.modelOutputMalformed
        }
    }

    func generateChoices(model: String, temperature: Double, context: String) async throws -> [ChoiceOption] {
        guard let url = URL(string: "/api/generate", relativeTo: baseURL) else { throw OllamaClientError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let preamble = """
        You are a narrative design assistant refreshing player choices for an in-progress interactive fiction story.
        Return STRICT JSON with field: options (array of {id:string,label:string}).
        Do not return narrative, markdown, or commentary—only JSON.

        Choice guidelines:
        - Provide 3-4 distinct options.
        - Write each as a first-person immediate action the protagonist might take next.
        - Keep each option under 18 words.
        - Reflect the current scene details, tone, and stakes provided in the context.
        - Ensure options diverge meaningfully; avoid near-duplicates or mutually exclusive contradictions.
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let prompt = "\(preamble)\n\nContext:\n\(context)\n\nTask: Produce only the refreshed options."

        let body = RequestBody(model: model, prompt: prompt, options: .init(temperature: temperature))
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaClientError.invalidResponse }
        guard http.statusCode == 200 else {
            if let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).error {
                throw OllamaClientError.serverError(message)
            }
            throw OllamaClientError.invalidResponse
        }

        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        guard let innerData = raw.response.data(using: .utf8) else { throw OllamaClientError.decodingFailed }

        do {
            let payload = try JSONDecoder().decode(ChoicesPayload.self, from: innerData)
            return payload.options
        } catch {
            throw OllamaClientError.modelOutputMalformed
        }
    }

    func fetchInstalledModels() async throws -> [String] {
        guard let url = URL(string: "/api/tags", relativeTo: baseURL) else { throw OllamaClientError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw OllamaClientError.invalidResponse }
        guard http.statusCode == 200 else {
            if let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).error {
                throw OllamaClientError.serverError(message)
            }
            throw OllamaClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
        return decoded.models.map(\.name)
    }
}
