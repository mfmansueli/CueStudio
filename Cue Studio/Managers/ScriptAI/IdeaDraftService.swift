//
//  IdeaDraftService.swift
//  Cue Studio
//

import Foundation

/// The idea the creator is writing or dictating on the empty Scripts screen: one copy of the text,
/// read and written by the card, the composer sheet and the generation flow, so a draft is never
/// lost or duplicated on its way from one to another. Kept on disk with its brief and the card's choices as they change (`DockDraft`),
/// so Cue closed by iOS finds it again; only a script written from it (once saved) or the creator clears it.
@MainActor
@Observable
final class IdeaDraftService {
    private(set) var draft = IdeaPromptDraft() {
        didSet { persist() }
    }

    /// What the creator chose on Generate with AI for this idea (nil: their default platform), kept
    /// here so closing that screen and opening it again finds the same choices.
    var platform: Platform? {
        didSet { persist() }
    }
    var length: ScriptLength = .auto {
        didSet { persist() }
    }
    /// The tile picked on the format sheet (Format ⌄ on the card); Auto picks from the idea.
    var formatChoice: FormatChoice = .auto {
        didSet { persist() }
    }
    /// How Cue structures the script: the picked format's type; nil for Auto and Talking head.
    var format: ScriptType? {
        get { formatChoice.scriptType }
        set { formatChoice = FormatChoice(newValue) }
    }
    /// The brand brief of a sponsored ad picked on the card: the ad is written from it, and from nothing else.
    var brand: BrandBrief? {
        didSet { persist() }
    }
    /// Who writes the idea: Apple Intelligence, or Ultra when the creator picked it on the dock (and allowed it). The creator's last pick stays,
    /// across scripts and launches (the owner's call, 29/10/2026): the writer chip always shows it.
    var engine: ScriptEngine = .apple {
        didSet { defaults?.set(engine.rawValue, forKey: DefaultsKey.dockWriter) }
    }
    /// "Let Cue draft it" in Start a video: the card takes the keyboard (it turns false again once it has).
    var wantsFocus = false
    /// The inspiration the text came from ("Start with it" in Find inspiration). Kept as it was given; what is sent is only what the text
    /// still says of it (`ScriptRequestFactory`), so a creator who changes the idea's direction is never overridden by the card.
    private(set) var brief: IdeaBrief? {
        didSet { persist() }
    }
    /// What the field held before "Start with it" replaced it: Undo puts it back.
    private(set) var replacedText: String?
    /// Where the writer's pick is kept between launches; nil keeps it for the session only.
    @ObservationIgnored private let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        engine = defaults?.string(forKey: DefaultsKey.dockWriter).flatMap(ScriptEngine.init(rawValue:)) ?? .apple
        // The dock as it was left (observers don't run here, so nothing is written back).
        if let saved = defaults?.data(forKey: DefaultsKey.dockDraft).flatMap({ try? JSONDecoder().decode(DockDraft.self, from: $0) }) {
            var restored = IdeaPromptDraft()
            restored.text = IdeaPromptDraft.limited(saved.text, replacing: "")
            draft = restored
            brief = saved.brief
            platform = saved.platform
            length = saved.length
            formatChoice = FormatChoice(id: saved.format) ?? .auto
            brand = saved.brand
        }
    }

    /// The dock as it is now: what a script sent from it compares with when it arrives (`ScriptStarter`), so a dock changed meanwhile is never
    /// cleared.
    var snapshot: DockDraft {
        DockDraft(text: draft.text, brief: brief, platform: platform, length: length, format: formatChoice.id, brand: brand)
    }

    private func persist() {
        guard let defaults else { return }
        let saved = snapshot
        if saved.isEmpty {
            defaults.removeObject(forKey: DefaultsKey.dockDraft)
        } else {
            defaults.set(try? JSONEncoder().encode(saved), forKey: DefaultsKey.dockDraft)
        }
    }

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

    // MARK: - Inspiration

    /// "Start with it": the whole brief in the field, to change before it is written. The format, platform and voice chosen on the card stay.
    /// What the field held is kept for `undoUse()`: an idea never silently replaces the creator's own.
    func use(_ idea: ThemeIdea) {
        let previous = draft.trimmedText
        replacedText = previous.isEmpty || previous == brief?.composerText ? nil : draft.text
        draft = IdeaPromptDraft()
        text = idea.brief?.composerText ?? idea.title
        brief = idea.brief
    }

    /// The field holds an inspiration exactly as "Start with it" put it there, and nothing of the creator's was replaced for it: nothing of
    /// theirs is in the field, so the dock's ↻ can pass it for the next idea (`dropIdea()`), as it passes a suggestion.
    var holdsUntouchedIdea: Bool {
        guard let brief, replacedText == nil else { return false }
        return draft.trimmedText == brief.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// ↻ on an untouched inspiration: the field empties, and the dock suggests the next idea in its place.
    func dropIdea() {
        guard holdsUntouchedIdea else { return }
        draft = IdeaPromptDraft()
        brief = nil
    }

    /// "Start with it" replaced text the creator had written: Undo can put it back.
    var canUndoUse: Bool { replacedText != nil }

    /// Undo after "Start with it": the creator's text comes back, without the brief.
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

    /// The idea became a script (or "Delete my Cue data"): the next one starts empty, with the choices back to the defaults, on disk too. The
    /// writer stays the creator's pick.
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
