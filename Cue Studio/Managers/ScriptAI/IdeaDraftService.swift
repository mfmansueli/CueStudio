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
    /// "↻ Another idea": which of the creator's starter ideas the card suggests while its field is empty.
    private(set) var suggestionRotation = 0
    /// "Let Cue write it" in Start a video: the card takes the keyboard (it turns false again once it has).
    var wantsFocus = false

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

    func canAskForIdea(isDictating: Bool) -> Bool {
        draft.canAskForIdea(isDictating: isDictating)
    }

    // MARK: - The suggested idea

    /// The idea the card suggests while the field is empty, from the creator's topics (Lifestyle until they choose).
    func suggestion(for niches: [Niche]) -> ThemeIdea? {
        ThemeCatalog.page(for: niches, rotation: suggestionRotation).first
    }

    func anotherSuggestion() {
        suggestionRotation += 1
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
    }
}
