//
//  IdeaPromptDraft.swift
//  Cue Studio
//

import Foundation

/// What the creator has put in the idea card of the empty Scripts screen: the text, shared by the
/// card, the composer sheet and the generation flow (`IdeaDraftService` holds the one copy). The
/// rules are here, apart from the views: nothing can be sent while the field holds only spaces or a
/// dictation is still writing, and a dictation only ever writes its own segment of the text.
nonisolated struct IdeaPromptDraft: Equatable, Sendable {
    var text = ""
    /// Set from the moment dictation starts until the last word has been written; nil otherwise.
    private(set) var dictation: DictationSegment?

    /// The text without the spaces around it: what is sent, and what decides whether anything can be.
    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The arrow is on when there is something to send and Apple Intelligence can write it. Never
    /// while a dictation is still writing: what is sent is what was reviewed.
    func canSubmit(isAvailable: Bool, isDictating: Bool = false) -> Bool {
        isAvailable && !isDictating && !trimmedText.isEmpty
    }

    /// What goes to the generation flow; nil while there is nothing to send.
    var submission: String? {
        trimmedText.isEmpty ? nil : trimmedText
    }

    // MARK: - Dictation

    /// Starts a dictation at `caret` (a character offset; nil is the end). Nothing is written yet.
    mutating func beginDictation(caret: Int?) {
        dictation = DictationSegment(in: text, caret: caret)
    }

    /// The transcript so far. Replaces only what the dictation wrote before; ignored when no
    /// dictation is running (a late result after the creator took over).
    mutating func hear(_ transcript: String) {
        guard var segment = dictation else { return }
        segment.hear(transcript)
        text = segment.text
        dictation = segment
    }

    /// Done writing: the words stay and the dictation lets go of them. Returns where they end.
    @discardableResult
    mutating func endDictation() -> Int? {
        defer { dictation = nil }
        guard let segment = dictation, segment.hasWords else { return nil }
        return segment.endOffset
    }

    /// The field changed under the dictation (typing, paste, autofill, Writing Tools): the
    /// dictation stops writing, so it can never overwrite what the creator just did.
    mutating func textChanged() {
        if let dictation, dictation.text != text { self.dictation = nil }
    }
}
