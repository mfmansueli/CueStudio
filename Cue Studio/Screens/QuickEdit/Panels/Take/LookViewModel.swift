//
//  LookViewModel.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The picture (`EditorPart`): Adjust and Auto, Skin, Filters, Background, Format with Follow face, Stabilize, Copy and Paste look,
/// for the whole take or the picked clip, and the recordings' motion analysis that Follow face and Stabilize read. What it keeps
/// is its panels' state; the look itself is in the edit, and every change is an undo step through the session.
///
/// Each part of the work is in its own extension (`+Adjust`, `+Auto`, `+Skin`, `+ClipScope`, `+Background`, `+CopyLook`, `+Format`,
/// `+FaceFollow`, `+Stabilize`, `+MotionAnalysis`).
@MainActor
@Observable
final class LookViewModel: EditorPart {
    /// Auto measuring the clip (`+Auto`).
    var autoState: AutoAdjustState = .idle
    /// ◐ in Adjust, Filters or Background: the preview shows the picture without Auto, Adjust, Skin, filter and background.
    var comparesPicture = false {
        didSet {
            guard comparesPicture != oldValue else { return }
            if comparesPicture { comparesSkin = false }
            session.showPlayedEdit()
        }
    }
    /// ◐ in Skin: the preview shows the video without Skin only (the color, the filter, the background and the texts stay).
    var comparesSkin = false {
        didSet {
            guard comparesSkin != oldValue else { return }
            if comparesSkin { comparesPicture = false }
            session.showPlayedEdit()
        }
    }
    /// The control Skin opens on, once (a notification's "Try it"); nil opens on the smoothing.
    var skinOpensOn: SkinControl?
    /// Whether this iPhone can find people in video; nil until checked.
    var canFindPeople: Bool?
    var isImportingBackground = false
    /// Adjust, Filters or Background was opened from a picked clip: it changes that clip only, and follows the picked clip.
    /// Opened from the main toolbar it changes the whole take.
    var lookScopeIsClip = false
    /// "Copy look": what a clip's look was when copied; nil until one is.
    var copiedLook: CopiedClipLook?
    /// "Paste look": which parts go, and whether its sheet is open.
    var pastesLookParts: Set<ClipLookPart> = Set(ClipLookPart.allCases)
    var showsPasteLook = false
    /// The recordings whose motion analysis was last asked for while the edit used it (`requestMotionAnalysisIfNeeded`).
    @ObservationIgnored var motionRequestedURLs: [URL] = []
    /// The take's upright frame in pixels, read when the recording opens (Follow face needs a format other than it).
    @ObservationIgnored var recordingUprightSize: CGSize?
    /// The pixels exporting an edit makes when its format's crop leaves fewer than its quality says ("606×1080"), by the rule of the
    /// review the editor opened from (`TakeReviewViewModel.reducedOutputSize(for:)`: the quality, Pro, the recording's frame); nil
    /// otherwise, and always nil where nothing exports from the editor.
    @ObservationIgnored var reducedExportSize: (TakeEdit) -> CGSize? = { _ in nil }

    let session: EditorSession
    /// Measures Auto.
    let editing: TakeEditing
    /// Analyzes the recordings' motion for Follow face and Stabilize; nil in tests that don't use it.
    let motion: MotionAnalysisService?

    init(session: EditorSession, editing: TakeEditing, motion: MotionAnalysisService?) {
        self.session = session
        self.editing = editing
        self.motion = motion
    }

    /// The edit changed: a comparison is no longer of what is shown, and a recording it plays now is analyzed when it needs to be.
    func editChanged() {
        if comparesPicture { comparesPicture = false }
        if comparesSkin { comparesSkin = false }
        requestMotionAnalysisIfNeeded()
    }

    /// The panel changed to `next`: leaving Adjust (or opening it again) never leaves a measurement running or
    /// the picture compared; Format and Stabilize get their recordings analyzed; closing every panel ends the clip's scope.
    func panelChanged(to next: EditorPanel?) {
        if next != .adjust { cancelAuto() }
        comparesPicture = false
        comparesSkin = false
        if next == .crop || next == .stabilize { requestMotionAnalysis() }
        if next == nil { lookScopeIsClip = false }
    }
}
