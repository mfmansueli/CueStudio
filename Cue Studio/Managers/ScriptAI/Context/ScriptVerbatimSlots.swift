import Foundation

/// Lets guided generation place requested exact wording without retyping its punctuation.
/// Only an emitted marker is restored; missing wording is never appended to a draft.
nonisolated struct ScriptVerbatimSlots {
    private static let prefix = "CUE_EXACT_TEXT_"
    private let phrases: [String]

    init(phrases: [String]) {
        // Avoid treating creator-supplied marker syntax as an internal instruction.
        self.phrases = phrases.contains(where: { $0.contains(Self.prefix) }) ? [] : phrases
    }

    var instruction: String {
        guard !phrases.isEmpty else { return "" }
        let mappings = phrases.enumerated().map { "\(Self.marker($0.offset)) represents exactly: \($0.element)" }
        return "\nExact wording placement: put each marker below unchanged in the spoken field where its phrase belongs. Cue will replace that emitted marker with the exact phrase. Do not translate, split or inflect the marker. Do not output this mapping or discuss it. Writing the actual phrase unchanged is also valid.\n" + mappings.joined(separator: "\n")
    }

    func restoring(in text: String) -> String {
        phrases.enumerated().reduce(text) { $0.replacingOccurrences(of: Self.marker($1.offset), with: $1.element) }
    }

    func hasUnresolvedMarker(in text: String) -> Bool { !phrases.isEmpty && text.contains(Self.prefix) }

    private static func marker(_ index: Int) -> String { "\(prefix)\(index)_END" }
}
