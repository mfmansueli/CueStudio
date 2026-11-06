//
//  OverlaysViewModel.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What lies on the video (`EditorPart`): texts and graphics with their type styles and "My style", photos and videos over the
/// take, their motion and keyframes, Track, and picking, dragging and placing them on the preview. What it keeps is its
/// panels' state; the overlays themselves are in the edit, and every change is an undo step through the session.
///
/// Each part of the work is in its own extension (`+Text`, `+TextStyle`, `+Style`, `+Media`, `+Mask`, `+Motion`, `+Track`,
/// `+Picking`, `+Preview`, `+Accessibility`).
@MainActor
@Observable
final class OverlaysViewModel: EditorPart {
    /// Where "Add photo or video" puts what is picked.
    var mediaInsertMode: MediaInsertMode = .split
    /// The overlay picked last, which Media opens on again (the "+" after the clips opens the sequence).
    var lastOverlayMode: MediaInsertMode = .split
    /// The area of the picked support's split screen its panel and the preview's gestures change.
    var selectedArea: SplitArea = .support
    /// The newest Split screen / Window / Full screen tap (`setMediaLayout`): an older one still finding a face is dropped.
    @ObservationIgnored var layoutRequest: UUID?
    /// Upright sizes of the recordings the main video plays (nil: the take), for the main area's gestures; read when a split
    /// screen is edited (`loadRecordingSizes`).
    var recordingSizes: [UUID?: CGSize] = [:]
    /// What Text style's look changes: this text or every text. The words, timing and motion are always the picked text's.
    var textStyleScope: TextStyleScope = .selected
    /// The section Text style › Custom last showed (Font, Color or Motion): where Custom opens again.
    var lastTextCustomSection: EditorPanelTab = .font
    /// The Text style panel's field takes the keyboard (a text was just added, or Edit was tapped).
    var focusesTextField = false
    /// The text being written in its sheet.
    var editingTextID: UUID?
    /// The text or photo or video a finger is moving on the preview: the video leaves it out meanwhile
    /// (`hidingDraggedOverlay(in:)`).
    var draggedOverlay: EditorSelection?
    /// A locked text a finger is on: it stays put, and the drag is still the text's, never the preview's swipe to full screen.
    var lockedUnderFinger: UUID?
    /// The text looks the creator saved, with favorites and the one new texts start in (`+TextLibrary`).
    var textStyles: StyleLibrary<TextLook>
    /// Track: how far following the picked item's object is, 0 to 1; nil when it isn't (`+Track`).
    var trackingProgress: Double?
    /// A video just added that has its own sound: Media asks whether to keep it.
    var soundChoiceMediaID: UUID?
    /// What a drag on the preview moves while Mask is open (`+Mask`).
    var maskDragTarget: MaskDragTarget = .mask
    /// Mask's ◐: the picked photo or video shows whole, without its mask.
    var comparesWithoutMask = false {
        didSet {
            guard comparesWithoutMask != oldValue else { return }
            session.showPlayedEdit()
        }
    }

    let session: EditorSession
    let styles: TextStyleStoring
    /// The scripts, for the audience comment a take's script answers (Comment card).
    let library: ScriptLibraryService
    /// Follows an object through a recording for Track.
    let tracker: ObjectTracking
    /// Finds the face a split-screen area is framed on when it's made.
    let faces: FaceFinding

    init(
        session: EditorSession, styles: TextStyleStoring, library: ScriptLibraryService, tracker: ObjectTracking,
        faces: FaceFinding = FaceFinder()
    ) {
        self.session = session
        self.styles = styles
        self.library = library
        self.tracker = tracker
        self.faces = faces
        textStyles = styles.textStyles
    }

    /// The edit changed: a video whose sound was being asked about and is gone isn't asked about any more.
    func editChanged() {
        if let id = soundChoiceMediaID, !edit.media.contains(where: { $0.id == id }) { soundChoiceMediaID = nil }
        if comparesWithoutMask { comparesWithoutMask = false }
    }
}
