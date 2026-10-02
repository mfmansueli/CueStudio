//
//  IdeaPromptDraft.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// What the creator has put in the empty Scripts screen's card: the text, and the kind of video
/// picked with it. The rules are here, apart from the view: a chip never touches the text, one
/// kind at a time, the same chip again goes back to a free idea, nothing can be sent while the
/// field holds only spaces, and a dictation only ever writes its own segment of the text.
struct IdeaPromptDraft: Equatable {
    var text = ""
    var idea: ScriptIdea?
    /// Set from the moment dictation starts until the last word has been written; nil otherwise.
    private(set) var dictation: DictationSegment?

    /// The text without the spaces around it: what is sent, and what decides whether anything can be.
    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The arrow is on when there is something to send and Apple Intelligence can write it. Never
    /// while a dictation is still writing: what is sent is what was reviewed.
    func canSubmit(isAvailable: Bool, isDictating: Bool = false) -> Bool {
        isAvailable && !isDictating && !trimmedText.isEmpty
    }

    /// Picks `option`, or takes it off when it was the one picked. Returns whether the field should
    /// take the keyboard (it should when a kind is picked, not when one is let go). The text is
    /// never changed.
    @discardableResult
    mutating func toggle(_ option: ScriptIdea) -> Bool {
        if idea == option {
            idea = nil
            return false
        }
        idea = option
        return true
    }

    /// What goes to the generation flow; nil while there is nothing to send.
    var seed: ScriptIdeaSeed? {
        trimmedText.isEmpty ? nil : ScriptIdeaSeed(text: trimmedText, idea: idea)
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

    /// The character offset of the insertion point in `text`; nil when the field has none (it was
    /// never focused). A selected range counts from its end: dictation adds after it, never over it.
    static func caretOffset(of selection: TextSelection?, in text: String) -> Int? {
        guard let selection else { return nil }
        let end: String.Index?
        switch selection.indices {
        case .selection(let range): end = range.upperBound
        case .multiSelection(let ranges): end = ranges.ranges.last?.upperBound
        @unknown default: end = nil
        }
        guard let end, end <= text.endIndex else { return nil }
        return text.distance(from: text.startIndex, to: end)
    }
}
