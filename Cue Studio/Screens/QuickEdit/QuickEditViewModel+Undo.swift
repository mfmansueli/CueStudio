//
//  QuickEditViewModel+Undo.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Undo and Redo (the player bar's, and the toasts' Undo): each says what it took back or put again, in the tool's own word
/// ("Undid · Split", "Redid · Clip 2", `EditStepSummary`), and when that lands out of sight on the timeline the playhead goes to it,
/// so the creator sees the result; a change already in view, or one of the whole video, moves nothing.
extension QuickEditViewModel {
    /// How far from the playhead (fixed in the middle) the timeline shows for sure, on the narrowest iPhone: a change further
    /// away is out of view.
    static let undoRevealReach: CGFloat = 150

    func undo() {
        let before = edit
        guard canUndo, document.undo() else { return }
        // Edit by text picks words by their place in the list, which an undone cut changes.
        clips.transcriptSelection = nil
        say(EditStepSummary(from: edit, to: before), undone: true)
    }

    func redo() {
        let before = edit
        guard canRedo, document.redo() else { return }
        clips.transcriptSelection = nil
        say(EditStepSummary(from: before, to: edit), undone: false)
    }

    /// The toast (VoiceOver hears it too) and, when it's out of view, the playhead on the change.
    private func say(_ step: EditStepSummary, undone: Bool) {
        toast.show(undone ? String(localized: "Undid · \(step.name)") : String(localized: "Redid · \(step.name)"))
        guard let span = step.span,
              let time = Self.revealTime(of: span, playhead: player.currentTime, zoom: timelineZoom, duration: edit.editedDuration)
        else { return }
        player.seek(to: time)
    }

    /// Where the playhead goes to show `span` (edited seconds), nil when the timeline already shows part of it around `playhead`
    /// at `zoom`: its start, or a little before the end of a video it would pass.
    static func revealTime(of span: TimeSpan, playhead: TimeInterval, zoom: CGFloat, duration: TimeInterval) -> TimeInterval? {
        let reach = TimeInterval(undoRevealReach / max(1, TimelineGeometry.basePointsPerSecond * zoom))
        guard span.end < playhead - reach || span.start > playhead + reach else { return nil }
        return min(max(0, span.start), max(0, duration - 0.03))
    }
}
