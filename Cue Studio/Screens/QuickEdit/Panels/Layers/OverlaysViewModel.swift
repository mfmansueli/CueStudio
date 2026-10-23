//
//  OverlaysViewModel.swift
//  Cue Studio
//

import Foundation

/// What lies on the video (`EditorPart`): texts and graphics with their type styles and "My style", photos and videos over the
/// take, their motion and keyframes, Track, and picking, dragging and placing them on the preview. What it keeps is its
/// panels' state; the overlays themselves are in the edit, and every change is an undo step through the session.
///
/// Each part of the work is in its own extension (`+Text`, `+TextStyle`, `+Style`, `+Media`, `+Motion`, `+Track`, `+Picking`,
/// `+Preview`, `+Accessibility`).
@MainActor
@Observable
final class OverlaysViewModel: EditorPart {
    /// Where "Add photo or video" puts what is picked.
    var mediaInsertMode: MediaInsertMode = .overlay
    /// What Text style's look changes: this text or every text. The words, timing and motion are always the picked text's.
    var textStyleScope: TextStyleScope = .selected
    /// The Text style panel's field takes the keyboard (a text was just added, or Edit was tapped).
    var focusesTextField = false
    /// The text being written in its sheet.
    var editingTextID: UUID?
    /// The text or photo or video a finger is moving on the preview: the video leaves it out meanwhile
    /// (`hidingDraggedOverlay(in:)`).
    var draggedOverlay: EditorSelection?
    /// The type the creator saved as "My style" (`+Style`).
    var myStyle: TextLook?
    /// Track: how far following the picked item's object is, 0 to 1; nil when it isn't (`+Track`).
    var trackingProgress: Double?
    /// A video just added that has its own sound: Media asks whether to keep it.
    var soundChoiceMediaID: UUID?

    let session: EditorSession
    /// Copies a picked photo or video into the edit's media.
    let importer: EditMediaImporting
    let styles: TextStyleStoring
    /// The scripts, for the audience comment a take's script answers (Comment card).
    let library: ScriptLibraryService
    /// Follows an object through a recording for Track.
    let tracker: ObjectTracking

    init(
        session: EditorSession, importer: EditMediaImporting, styles: TextStyleStoring, library: ScriptLibraryService, tracker: ObjectTracking
    ) {
        self.session = session
        self.importer = importer
        self.styles = styles
        self.library = library
        self.tracker = tracker
        myStyle = styles.myStyle
    }

    /// The edit changed: a video whose sound was being asked about and is gone isn't asked about any more.
    func editChanged() {
        if let id = soundChoiceMediaID, !edit.media.contains(where: { $0.id == id }) { soundChoiceMediaID = nil }
    }
}
