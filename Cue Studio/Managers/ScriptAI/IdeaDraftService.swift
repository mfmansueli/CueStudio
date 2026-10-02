//
//  IdeaDraftService.swift
//  Cue Studio
//

import Foundation

/// The idea the creator is writing or dictating on the empty Scripts screen: one copy of the text,
/// read and written by the card, the composer sheet and the generation flow, so a draft is never
/// lost or duplicated on its way from one to another. It lives with the app session, so closing the
/// composer keeps the draft in the card, and only a script written from it clears it.
@MainActor
@Observable
final class IdeaDraftService {
    private(set) var draft = IdeaPromptDraft()

    /// The text as the creator sees it. Writing it here (typing, paste, an example) ends a dictation
    /// that was still writing into it.
    var text: String {
        get { draft.text }
        set {
            guard newValue != draft.text else { return }
            draft.text = newValue
            draft.textChanged()
        }
    }

    var isEmpty: Bool { draft.trimmedText.isEmpty }

    /// What the generation flow writes from; nil while there is nothing to send.
    var submission: String? { draft.submission }

    func canSubmit(isAvailable: Bool, isDictating: Bool) -> Bool {
        draft.canSubmit(isAvailable: isAvailable, isDictating: isDictating)
    }

    // MARK: - Dictation

    func beginDictation(caret: Int?) {
        draft.beginDictation(caret: caret)
    }

    func hear(_ transcript: String) {
        draft.hear(transcript)
    }

    /// Returns where the dictated words end, or nil when nothing was dictated.
    @discardableResult
    func endDictation() -> Int? {
        draft.endDictation()
    }

    // MARK: - Clearing

    /// The idea became a script: the next one starts empty.
    func clear() {
        draft = IdeaPromptDraft()
    }
}
