//
//  QuickEditViewModel+Toasts.swift
//  Cue Studio
//

import Foundation

/// What every change made with one tap says: what happened and where ("Clip 2 deleted", "Photo added at 0:07"), with Undo
/// right there, so a tap in the wrong place costs one more tap and never a hunt for the undo button.
extension QuickEditViewModel {
    /// Undo, as the toast's button.
    var undoAction: ToastAction {
        ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
    }

    /// The toast for a change that can be taken back.
    func sayUndoable(_ message: String) {
        toast.show(message, action: undoAction)
    }

    /// "Clip 2" in a montage, "The clip" while the video is one clip.
    func clipName(at index: Int) -> String {
        edit.timeline.segments.count > 1 ? String(localized: "Clip \(index + 1)") : String(localized: "The clip")
    }

    /// The playhead's place, as the toasts say it ("0:07").
    var playheadPlace: String {
        DurationText.editor(player.currentTime)
    }
}
