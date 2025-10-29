import Foundation
import SwiftUI
import Combine

struct UserFacingError: Error {
    let message: String
}

@MainActor
final class GameViewModel: ObservableObject {
    // Settings
    @Published var provider: ModelProvider = .ollama {
        didSet {
            guard provider != oldValue else { return }
            clearNarrations()
            availableModels.removeAll()
            selectedModel = ""
            Task { await loadModelsIfNeeded(force: true) }
        }
    }
    @Published var selectedModel: String = ""
    @Published var temperature: Double = 0.9
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var currentScenario: String?

    // Session
    @Published var story = StoryState()
    @Published var isInSession: Bool = false

    // UI state
    @Published var isGenerating: Bool = false
    @Published var isLoadingModels: Bool = false
    @Published var isRefreshingChoices: Bool = false
    @Published var pendingCreativeDirection: String?
    @Published var errorMessage: String?
    @Published var groqAPIKey: String = ""
    @Published private(set) var narrationStates: [UUID: NarrationState] = [:]

    private let ollamaClient = OllamaClient()
    private let groqClient = GroqClient()

    private struct StoryTurnResult {
        let narrative: String
        let summary: String
        let options: [ChoiceOption]
    }

    struct NarrationState: Equatable {
        var isGenerating: Bool = false
        var audioURL: URL?
        var playbackRate: Float = 1.0
    }

    func beginSession(scenario: String?) {
        let trimmed = scenario?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentScenario = trimmed?.isEmpty == false ? trimmed : nil
        story.reset()
        clearNarrations()
        errorMessage = nil
        isInSession = true

        Task {
            await loadModelsIfNeeded()
            guard prepareSelectedModel() else {
                await MainActor.run {
                    self.isInSession = false
                    self.currentScenario = nil
                }
                return
            }
            _ = await generateNext(isRegeneration: false)
        }
    }

    func restartSession() {
        guard isInSession else { return }
        errorMessage = nil
        story.reset()
        clearNarrations()
        Task {
            guard prepareSelectedModel() else { return }
            _ = await generateNext(isRegeneration: false)
        }
    }

    func endSession() {
        story.reset()
        clearNarrations()
        isInSession = false
        currentScenario = nil
        errorMessage = nil
        isGenerating = false
    }

    func regenerateCurrentChapter() {
        guard let chapter = story.currentChapter else { return }
        regenerate(chapter: chapter)
    }

    func regenerateChoicesForCurrentChapter() {
        guard let chapter = story.currentChapter,
              chapter.selectedOptionId == nil else { return }
        regenerateChoices(for: chapter)
    }

    func regenerate(chapter: StoryChapter) {
        Task { [weak self] in
            guard let self else { return }
            guard prepareSelectedModel() else { return }
            await regenerateChapter(chapter)
        }
    }

    private func regenerateChoices(for chapter: StoryChapter) {
        Task { [weak self] in
            guard let self else { return }
            guard !self.isGenerating, !self.isRefreshingChoices else { return }
            guard self.prepareSelectedModel() else { return }
            await self.refreshOptions(chapter)
        }
    }

    func choose(_ option: ChoiceOption) {
        Task { [weak self] in
            guard let self else { return }
            guard prepareSelectedModel() else { return }
            story.markChoiceSelected(optionId: option.id)
            _ = await generateNext(isRegeneration: false) { [weak self] in
                self?.story.clearSelectionForCurrentChapter()
            }
        }
    }

    func submitWriteIn(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            guard prepareSelectedModel() else { return }
            guard let option = story.appendWriteInChoice(label: cleaned) else { return }
            let writeInID = option.id
            _ = await generateNext(isRegeneration: false) { [weak self] in
                self?.story.removeChoiceFromCurrentChapter(optionId: writeInID)
                self?.story.clearSelectionForCurrentChapter()
            }
        }
    }

    func setCreativeDirection(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingCreativeDirection = trimmed.isEmpty ? nil : trimmed
    }

    func clearCreativeDirection() {
        pendingCreativeDirection = nil
    }

    func refreshModels() {
        Task { await loadModelsIfNeeded(force: true) }
    }

    func narrationState(for chapterID: UUID) -> NarrationState {
        narrationStates[chapterID] ?? NarrationState()
    }

    func generateNarration(for chapter: StoryChapter) {
        guard provider == .groq else { return }
        let key = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorMessage = "Enter a Groq API key in Settings."
            return
        }

        let chapterID = chapter.id
        let previousState = narrationStates[chapterID]
        var state = previousState ?? NarrationState()
        if state.isGenerating { return }
        state.isGenerating = true
        state.audioURL = nil
        narrationStates[chapterID] = state

        Task {
            do {
                let audioData = try await groqClient.synthesizeSpeech(
                    text: chapter.narrative,
                    voice: "Adelaide-PlayAI",
                    apiKey: key
                )
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(chapterID.uuidString).wav")
                try audioData.write(to: outputURL, options: .atomic)

                await MainActor.run {
                    var updated = self.narrationStates[chapterID] ?? NarrationState()
                    updated.isGenerating = false
                    updated.audioURL = outputURL
                    self.narrationStates[chapterID] = updated
                }
                if let previousURL = previousState?.audioURL, previousURL != outputURL {
                    try? FileManager.default.removeItem(at: previousURL)
                }
            } catch {
                await MainActor.run {
                    if let previousState {
                        var restored = previousState
                        restored.isGenerating = false
                        self.narrationStates[chapterID] = restored
                    } else {
                        self.narrationStates[chapterID] = NarrationState()
                    }
                    self.present(error)
                }
            }
        }
    }

    func setNarrationRate(for chapterID: UUID, rate: Float) {
        var state = narrationStates[chapterID] ?? NarrationState()
        if abs(state.playbackRate - rate) < 0.0001 { return }
        state.playbackRate = rate
        narrationStates[chapterID] = state
    }

    private func regenerateChapter(_ chapter: StoryChapter) async {
        guard !isGenerating else { return }

        if let current = story.currentChapter, current.id == chapter.id {
            _ = await generateNext(isRegeneration: true)
        } else {
            let removedChapters = story.dropChapters(startingAt: chapter.id)
            let removedStates: [(UUID, NarrationState?)] = removedChapters.map { ($0.id, narrationStates[$0.id]) }
            let success = await generateNext(isRegeneration: false) { [weak self] in
                self?.story.restoreChapters(removedChapters)
                if let self {
                    for (id, state) in removedStates {
                        if let state {
                            self.narrationStates[id] = state
                        }
                    }
                }
            }
            if success {
                removedChapters.forEach { clearNarration(for: $0.id) }
            }
        }
    }

    private func refreshOptions(_ chapter: StoryChapter) async {
        guard !isRefreshingChoices else { return }
        errorMessage = nil
        isRefreshingChoices = true
        defer { isRefreshingChoices = false }

        do {
            let context = buildOptionsContext(for: chapter)
            let options = try await fetchChoices(context: context)
            story.replaceOptionsForCurrentChapter(with: options)
        } catch {
            present(error)
        }
    }

    private func fetchTurn(context: String) async throws -> StoryTurnResult {
        switch provider {
        case .ollama:
            let payload = try await ollamaClient.generateTurn(model: selectedModel, temperature: temperature, context: context)
            return StoryTurnResult(narrative: payload.narrative, summary: payload.summary, options: payload.options)
        case .groq:
            let key = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw UserFacingError(message: "Enter a Groq API key in Settings.")
            }
            let payload = try await groqClient.generateTurn(model: selectedModel, temperature: temperature, context: context, apiKey: key)
            return StoryTurnResult(narrative: payload.narrative, summary: payload.summary, options: payload.options)
        }
    }

    private func fetchChoices(context: String) async throws -> [ChoiceOption] {
        switch provider {
        case .ollama:
            return try await ollamaClient.generateChoices(model: selectedModel, temperature: temperature, context: context)
        case .groq:
            let key = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw UserFacingError(message: "Enter a Groq API key in Settings.")
            }
            return try await groqClient.generateChoices(model: selectedModel, temperature: temperature, context: context, apiKey: key)
        }
    }

    private func present(_ error: Error) {
        if let userError = error as? UserFacingError {
            errorMessage = userError.message
        } else if let clientError = error as? OllamaClientError {
            errorMessage = clientError.errorDescription ?? clientError.localizedDescription
        } else if let groqError = error as? GroqClientError {
            errorMessage = groqError.errorDescription ?? groqError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    private func generateNext(isRegeneration: Bool, onFailure: (() -> Void)? = nil) async -> Bool {
        guard !isGenerating else { return false }
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        let context = buildContext(includeVariantHint: isRegeneration)
        do {
            let result = try await fetchTurn(context: context)

            if var last = story.currentChapter, isRegeneration {
                clearNarration(for: last.id)
                last.narrative = result.narrative
                last.summary = result.summary
                last.choices = result.options
                last.regenerationCount += 1
                story.replaceLast(with: last)
                pendingCreativeDirection = nil
            } else {
                let chapter = StoryChapter(
                    narrative: result.narrative,
                    summary: result.summary,
                    choices: result.options,
                    regenerationCount: 1,
                    selectedOptionId: nil
                )
                story.append(chapter)
                clearNarration(for: chapter.id)
                pendingCreativeDirection = nil
            }
            return true
        } catch {
            onFailure?()
            present(error)
            return false
        }
    }

    private func buildContext(includeVariantHint: Bool) -> String {
        if story.currentChapter == nil {
            if let scenario = currentScenario, !scenario.isEmpty {
                return scenario
            } else {
                let seed = """
                Genre: Atmospheric fantasy adventure.
                Tone: Reflective, grounded, lightly mysterious. Avoid modern slang.
                Opening premise: The protagonist encounters a quiet fork in the path at dusk.
                Key characters: The traveler (narrator), a soft-spoken guide named Ilya, and a mischievous fox-spirit Kerren.
                Dialogue requirements: Use Character Name: "Line." formatting with each speaker on its own line. Include at least three lines of dialogue interspersed with narration.
                Narrative pacing: Allow space for atmospheric exposition between exchanges.
                Decision integration: Whenever the player chooses an option, treat it as their deliberate action and describe its impact within the next passage.
                """.trimmingCharacters(in: .whitespacesAndNewlines)
                return seed
            }
        }

        let transcript = story.narrativeTranscript(maxBeats: 8)
        let nextChapterNumber = story.chapters.count + 1
        let latestDecisionNote: String = {
            guard
                let last = story.currentChapter,
                let sel = last.selectedOptionId,
                let label = last.choices.first(where: { $0.id == sel })?.label
            else { return "" }
            return """

            Latest player decision: "\(label)". Treat this as an action already underway; open the next passage by acknowledging and responding to it.
            """
        }()
        let creativeDirectionNote: String = {
            guard let direction = pendingCreativeDirection, !direction.isEmpty else { return "" }
            return """

            Player creative direction for Chapter \(nextChapterNumber): "\(direction)".
            Weave these intentions organically into the unfolding scene using fresh wording—do not quote the guidance verbatim.
            """
        }()
        let latestClosingCue: String = {
            guard let cue = story.latestContinuationCue() else { return "" }
            return """

            Latest closing passage (context only—continue immediately afterward; do not reuse its sentences):
            \(cue)
            """
        }()
        let continuityReminder = """
        You are now writing Chapter \(nextChapterNumber). It must push the plot into new territory—no recaps beyond a single fresh sentence, and absolutely no re-use of wording from earlier chapters. Transition immediately into the consequences of the latest decision.
        """

        if includeVariantHint {
            return """
            Here is a running transcript of the story so far. Each chapter already reflects prior dialogue and, when present, the player's decision.
            
            \(transcript)
            
            Variant request: Please produce a distinctly different variant (new imagery, dialogue beats, and pacing) while preserving the dialogue formatting instructions. Avoid echoing lines from the latest chapter.
            \(latestDecisionNote)
            \(creativeDirectionNote)
            \(latestClosingCue)
            \(continuityReminder)
            """
        }
        return """
        Continue this single continuous story. Respect the previous chapters and decisions recorded below. Use fresh prose that advances the plot; never repeat or lightly paraphrase material from the transcript. You may summarize prior events in one short sentence before moving forward.

        \(transcript)
        \(latestDecisionNote)
        \(creativeDirectionNote)
        \(latestClosingCue)
        \(continuityReminder)
        """
    }

    private func buildOptionsContext(for chapter: StoryChapter) -> String {
        let transcript = story.narrativeTranscript(maxBeats: 8)
        let chapterIndex = story.indexOfChapter(id: chapter.id) ?? max(story.chapters.count - 1, 0)
        let chapterNumber = chapterIndex + 1
        let closingCue = story.latestContinuationCue() ?? ""
        let decisionLine: String = {
            if let sel = chapter.selectedOptionId,
               let label = chapter.choices.first(where: { $0.id == sel })?.label {
                return """
                Latest player selection already locked in: "\(label)". Proposed options must respect that commitment.
                """
            }
            return "No option has been chosen yet; propose fresh actionable directions for the protagonist to take next."
        }()

        return """
        Story summary so far (chronological, do not rewrite):
        \(transcript)

        Current chapter \(chapterNumber) full text (for reference only—do not reuse its sentences verbatim):
        \(chapter.narrative)

        Current chapter synopsis:
        \(chapter.summary)

        Scene closing beat (continue immediately afterward; avoid repeating):
        \(closingCue)

        \(decisionLine)
        """
    }

    private func loadModelsIfNeeded(force: Bool = false) async {
        if provider == .groq {
            isLoadingModels = false
            availableModels = GroqClient.supportedModels
            if !availableModels.contains(selectedModel) {
                selectedModel = availableModels.first ?? ""
            }
            return
        }

        if isLoadingModels { return }
        if !force, !availableModels.isEmpty { return }

        isLoadingModels = true
        defer { isLoadingModels = false }

        do {
            let models = try await ollamaClient.fetchInstalledModels()
            availableModels = models
            if !models.isEmpty {
                errorMessage = nil
            }
            if !availableModels.contains(selectedModel) {
                selectedModel = availableModels.first ?? ""
            }
            if availableModels.isEmpty {
                errorMessage = "No Ollama models installed. Pull one in the Ollama app, then return here to begin."
            }
        } catch {
            availableModels = []
            selectedModel = ""
            present(error)
        }
    }

    private func clearNarrations() {
        let urls = narrationStates.values.compactMap(\.audioURL)
        narrationStates.removeAll()
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func clearNarration(for chapterID: UUID) {
        if let state = narrationStates.removeValue(forKey: chapterID),
           let url = state.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func prepareSelectedModel() -> Bool {
        switch provider {
        case .ollama:
            if availableModels.isEmpty {
                errorMessage = "No Ollama models installed. Pull a model and try again."
                return false
            }

            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }

            guard !selectedModel.isEmpty else {
                errorMessage = "Select an installed model before continuing."
                return false
            }

            if !availableModels.contains(selectedModel), let first = availableModels.first {
                selectedModel = first
            }

            return availableModels.contains(selectedModel)

        case .groq:
            if availableModels.isEmpty {
                availableModels = GroqClient.supportedModels
            }

            let key = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                errorMessage = "Enter a Groq API key in Settings."
                return false
            }

            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }

            guard !selectedModel.isEmpty else {
                errorMessage = "Select a Groq model before continuing."
                return false
            }

            if !availableModels.contains(selectedModel), let first = availableModels.first {
                selectedModel = first
            }

            return availableModels.contains(selectedModel)
        }
    }
}
