//
//  IdeaPromptDraft.swift
//  Cue Studio
//

import Foundation

/// What the creator has put in the empty Scripts screen's card: the text, and the kind of video
/// picked with it. The rules are here, apart from the view: a chip never touches the text, one
/// kind at a time, the same chip again goes back to a free idea, and nothing can be sent while the
/// field holds only spaces.
struct IdeaPromptDraft: Equatable {
    var text = ""
    var idea: ScriptIdea?

    /// The text without the spaces around it: what is sent, and what decides whether anything can be.
    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The arrow is on when there is something to send and Apple Intelligence can write it.
    func canSubmit(isAvailable: Bool) -> Bool {
        isAvailable && !trimmedText.isEmpty
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
}
