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
/// `+MyStyle`, `+Translation`, `+Preview`).
@MainActor
@Observable
final class CaptionsViewModel: EditorPart {
    /// Captions listening to the take (`+Lines`).
    var captionState: CaptionState = .idle
    /// Asking before new captions replace lines the creator corrected or wrote.
    var confirmsCaptionReplacement = false
    /// Captions › Select: the lines picked to be styled, moved or deleted together (`+Picks`); nil while lines are picked one
    /// at a time.
    var captionPicks: Set<UUID>?
    /// The picked caption line's field takes the keyboard (a line was just added).
    var focusesCaptionField = false
    /// The text whose look "Apply this style to captions" is asking to copy; nil when not asking.
    var captionStyleCopySourceID: UUID?
    /// The captions' saved "My style" (`+MyStyle`).
    var myCaptionStyle: MyCaptionStyle?
    /// The Translate sheet is open.
    var showsTranslation = false
    /// Translating the captions (`+Translation`).
    var translationState: TranslationState = .idle
    /// The translation the view asks the system for; nil when none is wanted.
    var translationRequest: TranslationRequest?
    /// Listening was asked for Edit by text: the captions it makes stay hidden if they were.
    var keepsCaptionsHiddenAfterListening = false
    /// The lines timed to the edit, kept until the lines or the cuts change (`captionMap`).
    @ObservationIgnored var captionMapStore: CaptionMap?

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
        myCaptionStyle = styles.myCaptionStyle
    }

    /// The edit changed (from `previous`): the lines timed to it are worked out again when the lines or the cuts moved.
    func editChanged(from previous: TakeEdit) {
        if previous.captions != edit.captions || previous.timeline != edit.timeline { captionMapStore = nil }
    }

    /// The panel changed to `next`: picking several lines belongs to the list of lines.
    func panelChanged(to next: EditorPanel?) {
        if next != .captions { captionPicks = nil }
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
