//
//  IdeaDraftService.swift
//  Cue Studio
//

import Foundation

/// The idea the creator is writing or dictating on the empty Scripts screen: one copy of the text,
/// read and written by the card, the composer sheet and the generation flow, so a draft is never
/// lost or duplicated on its way from one to another. It lives with the app session, so closing
/// Generate with AI keeps the draft in the card, and only a script written from it clears it.
@MainActor
@Observable
final class IdeaDraftService {
    private(set) var draft = IdeaPromptDraft()

    /// What the creator chose on Generate with AI for this idea (nil: their default platform), kept
    /// here so closing that screen and opening it again finds the same choices.
    var platform: Platform?
    var length: ScriptLength = .auto
    /// The tile picked on the format sheet (Format ⌄ on the card); Auto picks from the idea.
    var formatChoice: FormatChoice = .auto
    /// How Cue structures the script: the picked format's type; nil for Auto and Talking head.
    var format: ScriptType? {
        get { formatChoice.scriptType }
        set { formatChoice = FormatChoice(newValue) }
    }
    /// The brand brief of a sponsored ad picked on the card: the ad is written from it, and from nothing else.
    var brand: BrandBrief?
    /// "Let Cue write it" in Start a video: the card takes the keyboard (it turns false again once it has).
    var wantsFocus = false
    /// The inspiration the text came from ("Use this idea" in Find inspiration). Kept as it was given; what is sent is only what the text
    /// still says of it (`submittedBrief`), so a creator who changes the idea's direction is never overridden by the card.
    private(set) var brief: IdeaBrief?
    /// What the field held before "Use this idea" replaced it: Undo puts it back.
    private(set) var replacedText: String?

    /// The text as the creator sees it. Writing it here (typing, paste, an example) ends a dictation
    /// that was still writing into it. It never goes past `IdeaPromptDraft.maxCharacters`.
    var text: String {
        get { draft.text }
        set {
            let limited = IdeaPromptDraft.limited(newValue, replacing: draft.text)
            guard limited != draft.text else { return }
            draft.text = limited
            draft.textChanged()
        }
    }

    var isEmpty: Bool { draft.trimmedText.isEmpty }

    /// What the generation flow writes from; nil while there is nothing to send.
    var submission: String? { draft.submission }

    /// The brief that goes with `submission`: what of it the text still says.
    var submittedBrief: IdeaBrief? {
        guard let text = submission else { return nil }
        return brief?.standing(in: text)
    }

    // MARK: - Inspiration

    /// "Use this idea": the whole brief in the field, to change before it is written. The format, platform and voice chosen on the card stay.
    /// What the field held is kept for `undoUse()`: an idea never silently replaces the creator's own.
    func use(_ idea: ThemeIdea) {
        let previous = draft.trimmedText
        replacedText = previous.isEmpty || previous == brief?.composerText ? nil : draft.text
        draft = IdeaPromptDraft()
        text = idea.brief?.composerText ?? idea.title
        brief = idea.brief
    }

    /// "Use this idea" replaced text the creator had written: Undo can put it back.
    var canUndoUse: Bool { replacedText != nil }

    /// Undo after "Use this idea": the creator's text comes back, without the brief.
    func undoUse() {
        guard let replacedText else { return }
        draft = IdeaPromptDraft()
        text = replacedText
        brief = nil
        self.replacedText = nil
    }

    func canSubmit(isAvailable: Bool, isDictating: Bool) -> Bool {
        draft.canSubmit(isAvailable: isAvailable, isDictating: isDictating)
    }

    func canAskForIdea(isDictating: Bool) -> Bool {
        draft.canAskForIdea(isDictating: isDictating)
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

    /// The idea became a script: the next one starts empty, with the choices back to the defaults.
    func clear() {
        draft = IdeaPromptDraft()
        platform = nil
        length = .auto
        formatChoice = .auto
        brand = nil
        brief = nil
        replacedText = nil
    }
}
