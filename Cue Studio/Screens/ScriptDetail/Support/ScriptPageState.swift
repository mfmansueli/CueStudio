//
//  ScriptPageState.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// What the script page holds while it is open: the words being written (committed to the library
/// as the creator goes), which face is showing, and the little states around them. It is the
/// page's own copy; `ScriptDetailViewModel.commitPage()` is what writes it back.
struct ScriptPageState {
    var isLoaded = false
    var title = ""
    var text = ""
    var textSize: ScriptTextSize = .medium
    /// What the creator has selected (characters from the start of the text), for the AI bar.
    var selection: Range<Int>?
    /// The AI's words in place of a selection, waiting for Keep, Undo or Try again.
    var passage: AIPassage?
    /// The words were edited this visit (not just opened): leaving without Done makes the script a draft.
    var isEdited = false
    /// Done was tapped this visit.
    var isDone = false
    /// "{n} sections are still empty": Done anyway / Keep writing.
    var emptySectionsToConfirm: Int?
    /// Asked for the text to take the keyboard (a draft opened with "Continue").
    var focusesText = false
    var dismissedTips: Set<String> = []
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
    /// Why the last writing failed; the page offers "Try again".
    var writingError: String?
    /// The voice comparison on a script just written in the creator's voice.
    var voicePreview: VoicePreview?
    /// The Adjust sheet is open.
    var showsVoiceAdjust = false
    /// Writing changed the words of a script that has takes: the version went up once for this visit.
    var bumpedVersion = false
}
