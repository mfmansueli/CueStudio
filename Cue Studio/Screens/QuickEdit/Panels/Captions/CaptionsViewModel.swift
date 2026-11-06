//
//  CaptionsViewModel.swift
//  Cue Studio
//

import Foundation

/// The editor's captions (`EditorPart`): made from what is said in the take, corrected line by line, picked and changed
/// together, found and replaced, styled, translated, and moved on the preview. What it keeps is its panels' state; the lines
/// themselves are in the edit, and every change to them is an undo step through the session.
///
/// Each part of the work is in its own extension (`+Lines`, `+LineByLine`, `+Panels`, `+Picks`, `+Find`, `+StyleCopy`,
/// `+Catalog`, `+Library`, `+Adjust`, `+Motion`, `+Emphasis`, `+Format`, `+Translation`, `+Preview`).
@MainActor
@Observable
final class CaptionsViewModel: EditorPart {
    /// Captions listening to the take (`+Lines`).
    var captionState: CaptionState = .idle
    /// Asking before new captions replace lines the creator corrected or wrote.
    var confirmsCaptionReplacement = false
    /// Asking before Delete all takes every line (`+LineByLine`).
    var confirmsDeletingAll = false
    /// Captions › Select: the lines picked to be styled, moved or deleted together (`+Picks`); nil while lines are picked one
    /// at a time.
    var captionPicks: Set<UUID>?
    /// The picked caption line's field takes the keyboard (a line was just added).
    var focusesCaptionField = false
    /// The line whose More opens on its own (Emphasis on a caption's toolbar): its words to emphasize, at hand.
    var expandedLineID: UUID?
    /// The text whose look "Apply this style to captions" is asking to copy; nil when not asking.
    var captionStyleCopySourceID: UUID?
    /// The creator's saved caption styles, with favorites and the one new captions start in (`+Library`).
    var captionStyles: StyleLibrary<MyCaptionStyle>
    /// Caption style › Styles' filter, kept as it was left (`+Catalog`).
    var captionCatalogFilter: CaptionCatalogFilter
    /// The card last picked in Styles, while Styles offers its own size and place (`+Catalog`).
    var lastPickedCaptionCard: CaptionStyleCard.Kind?
    /// Caption style › Adjust's warning: the look as it is would be hard to read on bright scenes (`+Adjust`).
    var captionContrastWarning = false
    /// How far Styles was scrolled, kept while the editor is open (`+Catalog`): back from another tab, the cards are where they
    /// were.
    @ObservationIgnored var captionCatalogOffset: CGFloat = 0
    /// What the Styles cards say, taken when Caption style opens (`+Catalog`): the cards don't redraw as the video plays.
    var captionSampleWords: [String] = []
    /// The Translate sheet is open.
    var showsTranslation = false
    /// Translating the captions (`+Translation`).
    var translationState: TranslationState = .idle
    /// The translation the view asks the system for; nil when none is wanted.
    var translationRequest: TranslationRequest?
    /// The availability check under way (`translateCaptions`): Cancel clears it, and a check that comes back after isn't used.
    @ObservationIgnored var translationCheck: UUID?
    /// Listening was asked for Edit by text: the captions it makes stay hidden if they were.
    var keepsCaptionsHiddenAfterListening = false
    /// The lines timed to the edit, kept until the lines or the cuts change (`captionMap`).
    @ObservationIgnored var captionMapStore: CaptionMap?
    /// The video over the take whose voice is being listened to (`setCaptionsItsVoice`): turning it off stops that.
    @ObservationIgnored var listeningSupportID: UUID?

    let session: EditorSession
    let editing: TakeEditing
    /// The library of takes: a montage's other takes are heard with their own scripts.
    let takes: TakeLibraryService
    let library: ScriptLibraryService
    let styles: TextStyleStoring
    let translations: TranslationAvailabilityChecking
    /// What a script is heard in (`LanguageService.captionRequest(for:)`).
    let speechLanguageFor: (Script?) -> SpeechLanguageRequest
    /// The languages a take without a script is likely spoken in (`LanguageService.likelySpokenLanguages(for:)`).
    let likelySpokenLanguagesFor: (Script?) -> [CueLanguage]
    /// Voice Following's language when it differs from the captions' (`LanguageService.languageConflict(for:)`).
    private let languageConflictFor: (Script?) -> SpeechLanguageConflict?

    init(
        session: EditorSession, editing: TakeEditing, takes: TakeLibraryService, library: ScriptLibraryService,
        styles: TextStyleStoring, translations: TranslationAvailabilityChecking,
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest,
        likelySpokenLanguages: @escaping (Script?) -> [CueLanguage],
        languageConflict: @escaping (Script?) -> SpeechLanguageConflict?
    ) {
        self.session = session
        self.editing = editing
        self.takes = takes
        self.library = library
        self.styles = styles
        self.translations = translations
        speechLanguageFor = speechLanguage
        likelySpokenLanguagesFor = likelySpokenLanguages
        languageConflictFor = languageConflict
        captionStyles = styles.captionStyles
        captionCatalogFilter = CaptionCatalogFilter(rawValue: styles.captionCatalogFilter)
    }

    /// The edit changed (from `previous`): the lines timed to it are worked out again when the lines or the cuts moved.
    func editChanged(from previous: TakeEdit) {
        if previous.captions != edit.captions || previous.timeline != edit.timeline { captionMapStore = nil }
    }

    /// The panel changed to `next`: picking several lines belongs to the list of lines, and the offer of a style's own size and
    /// place to Caption style.
    func panelChanged(to next: EditorPanel?) {
        if next != .captions { captionPicks = nil }
        if next != .captionStyle { lastPickedCaptionCard = nil }
        if next == .captionStyle {
            captionSampleWords = currentSampleWords
            checkCaptionContrast()
        }
    }

    // MARK: - The take

    /// The take's script, or nothing for a freestyle take.
    var scriptText: String {
        session.captionScript?.text ?? ""
    }

    /// Said under Captions while they listen in the script's language (Automatic) and Voice Following listens in another one,
    /// so the two never disagree silently.
    var captionLanguageConflict: SpeechLanguageConflict? {
        guard edit.captionLanguage == nil else { return nil }
        return languageConflictFor(session.captionScript)
    }
}
