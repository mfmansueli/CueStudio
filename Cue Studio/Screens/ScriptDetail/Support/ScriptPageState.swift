//
//  ScriptPageState.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// What the script page holds while it is open: the words being written (committed to the library
/// as the creator goes), which face is showing, and the little states around them. It is the
/// page's own copy; `ScriptDetailViewModel.commitPage()` is what writes it back. Observed field by field (a class), so a view is redrawn
/// only by what it shows: a letter typed changes `text`, which only the editor reads; the page around the words reads `measured`, which
/// catches up when the typing pauses. The title is beside it (`ScriptDetailViewModel.pageTitle`).
@Observable
final class ScriptPageState {
    var isLoaded = false
    /// The words on the page. Changed by anything but the creator's typing (the page opening, the AI, a tool, a cue from the bar), the
    /// page measures them at once (`measured`); typed (`type(_:)`), they wait for the pause.
    var text = "" {
        didSet { if !isTyping { catchUp() } }
    }
    /// The words as the page around them measures them (the length, the strip, which tools there are, the language): `text`, except
    /// while the creator types, when they wait for the typing to pause (`ScriptDetailViewModel.wordsTyped()`). A letter never makes the
    /// page measure the whole script again (the owner, 03/11/2026: typing as fluid as in Notes, whatever the script's length).
    private(set) var measured = ""
    /// No words on the page (the editor's placeholder), told at once: it changes only when the page empties or gets its first letter.
    private(set) var isEmpty = true
    @ObservationIgnored private var isTyping = false
    /// Where the caret is (UTF-16, as the text view counts), kept without telling anyone: a caret moving as letters are typed redraws
    /// nothing. A cue from the bar goes in there (`selection` is only a real selection, which the AI bar needs).
    @ObservationIgnored var caret: Int?
    var textSize: ScriptTextSize = .medium
    /// What the creator has selected (characters from the start of the text), for the AI bar.
    var selection: Range<Int>?
    /// The AI's words in place of a selection, waiting for Keep, Undo or Try again.
    var passage: AIPassage?
    /// The words were edited this visit (not just opened): leaving without Done makes the script a draft.
    var isEdited = false
    /// Done was tapped this visit.
    var isDone = false
    /// "{n} sections are still empty": Mark ready anyway / Keep writing.
    var emptySectionsToConfirm: Int?
    /// Asked for the text to take the keyboard (a draft opened with "Continue").
    var focusesText = false
    /// The "A bit long for TikTok" question was asked once for this page.
    var askedAboutLength = false
    var showsLengthNudge = false
    /// Asked for the title to take the keyboard (a script with nothing in it yet).
    var focusesTitle = false
    /// A tool is working on the selection.
    var isRewriting = false
    /// The AI is writing the script (the model is working, or its words are arriving).
    var isWriting = false
    /// The words that have arrived so far while they come in; nil otherwise.
    var revealed: String?
    /// How much of the script the AI has written, while the page waits for it (the pill's percentage); nil otherwise.
    var progress: WritingProgressMeter?
    /// The voice comparison on a script just written in the creator's voice.
    var voicePreview: VoicePreview?
    /// The Adjust sheet is open.
    var showsVoiceAdjust = false
    /// Writing changed the words of a script that has takes: the version went up once for this visit.
    var bumpedVersion = false

    /// Words from the editor (a letter typed, an undo, a cue deleted with backspace): `text` changes at once, `measured` at the pause.
    func type(_ words: String) {
        isTyping = true
        text = words
        isTyping = false
        if words.isEmpty != isEmpty { isEmpty = words.isEmpty }
    }

    /// The page's measures catch up with the words (the typing paused). Nothing is told when they already agree.
    func catchUp() {
        if measured != text { measured = text }
        if text.isEmpty != isEmpty { isEmpty = text.isEmpty }
    }
}
