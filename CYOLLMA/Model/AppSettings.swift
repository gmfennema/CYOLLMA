import Foundation

enum ModelProvider: String, CaseIterable, Identifiable, Codable {
    case ollama
    case groq

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (local)"
        case .groq: return "Groq (cloud)"
        }
    }
}
