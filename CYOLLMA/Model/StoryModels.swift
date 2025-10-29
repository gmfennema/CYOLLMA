import Foundation
import SwiftUI
import Combine

struct ChoiceOption: Identifiable, Hashable, Codable {
    var id: String
    var label: String
}

struct StoryChapter: Identifiable, Hashable, Codable {
    let id: UUID
    var narrative: String
    var summary: String
    var choices: [ChoiceOption]
    var regenerationCount: Int
    var selectedOptionId: String?

    init(
        id: UUID = UUID(),
        narrative: String,
        summary: String,
        choices: [ChoiceOption],
        regenerationCount: Int = 1,
        selectedOptionId: String? = nil
    ) {
        self.id = id
        self.narrative = narrative
        self.summary = summary
        self.choices = choices
        self.regenerationCount = regenerationCount
        self.selectedOptionId = selectedOptionId
    }
}

@MainActor
final class StoryState: ObservableObject {
    @Published private(set) var chapters: [StoryChapter] = []

    var currentChapter: StoryChapter? { chapters.last }

    func reset() {
        chapters.removeAll()
    }

    func append(_ chapter: StoryChapter) {
        chapters.append(chapter)
    }

    @discardableResult
    func dropChapters(startingAt chapterID: UUID) -> [StoryChapter] {
        guard let index = chapters.firstIndex(where: { $0.id == chapterID }) else { return [] }
        let removed = Array(chapters[index..<chapters.count])
        chapters.removeSubrange(index..<chapters.count)
        return removed
    }

    func restoreChapters(_ chaptersToRestore: [StoryChapter]) {
        guard !chaptersToRestore.isEmpty else { return }
        chapters.append(contentsOf: chaptersToRestore)
    }

    func replaceLast(with chapter: StoryChapter) {
        guard !chapters.isEmpty else { return }
        chapters[chapters.count - 1] = chapter
    }

    func markChoiceSelected(optionId: String) {
        guard !chapters.isEmpty else { return }
        chapters[chapters.count - 1].selectedOptionId = optionId
    }

    func appendWriteInChoice(label: String) -> ChoiceOption? {
        guard !chapters.isEmpty else { return nil }
        var chapter = chapters[chapters.count - 1]
        let option = ChoiceOption(id: "writein-\(UUID().uuidString)", label: label)
        chapter.choices.append(option)
        chapter.selectedOptionId = option.id
        chapters[chapters.count - 1] = chapter
        return option
    }

    func clearSelectionForCurrentChapter() {
        guard !chapters.isEmpty else { return }
        chapters[chapters.count - 1].selectedOptionId = nil
    }

    func removeChoiceFromCurrentChapter(optionId: String) {
        guard !chapters.isEmpty else { return }
        chapters[chapters.count - 1].choices.removeAll { $0.id == optionId }
    }

    func indexOfChapter(id: UUID) -> Int? {
        chapters.firstIndex(where: { $0.id == id })
    }

    func replaceOptionsForCurrentChapter(with options: [ChoiceOption]) {
        guard !chapters.isEmpty else { return }
        chapters[chapters.count - 1].choices = options
        chapters[chapters.count - 1].selectedOptionId = nil
    }

    func latestContinuationCue(maxCharacters: Int = 320) -> String? {
        guard let narrative = chapters.last?.narrative.trimmingCharacters(in: .whitespacesAndNewlines),
              !narrative.isEmpty else { return nil }

        let paragraphs = narrative.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let tail = paragraphs.last ?? narrative
        if tail.count <= maxCharacters { return tail }
        let start = tail.index(tail.endIndex, offsetBy: -maxCharacters)
        return String(tail[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func narrativeTranscript(maxBeats: Int = 8) -> String {
        let recent = chapters.suffix(maxBeats)
        let startIndex = max(chapters.count - recent.count, 0)
        let segments: [String] = recent.enumerated().map { offset, chapter in
            let chapterNumber = startIndex + offset + 1
            let decisionLine: String
            if let sel = chapter.selectedOptionId,
               let label = chapter.choices.first(where: { $0.id == sel })?.label {
                decisionLine = "Decision: \(label)"
            } else {
                decisionLine = "Decision: (pending)"
            }

            return """
            ---
            Chapter \(chapterNumber)
            \(decisionLine)
            Summary: \(chapter.summary)
            """
        }
        return segments.joined(separator: "\n\n")
    }
}
