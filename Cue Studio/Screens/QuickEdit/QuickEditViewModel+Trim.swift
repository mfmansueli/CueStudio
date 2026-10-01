//
//  QuickEditViewModel+Trim.swift
//  Cue Studio
//

import Foundation

/// The cuts between clips (their transitions), the outer handles, "Remove part" and cutting at the
/// playhead. Each change is one undo step.
extension QuickEditViewModel {
    // MARK: - Transitions

    /// A tap on the mark of the cut before the section at `index`: selects that cut so its
    /// transition can be picked, or lets go of it when it was already selected.
    /// Lets go of the section and the cut picked on the strip (a bar on a track was picked).
    func clearStripSelection() {
        selectedSegmentID = nil
        selectedJoinID = nil
    }

    func tapJoin(_ index: Int) {
        guard removalRange == nil, index > 0, edit.timeline.segments.indices.contains(index) else { return }
        clearLayerSelection()
        let id = edit.timeline.segments[index].id
        selectedSegmentID = nil
        selectedJoinID = selectedJoinID == id ? nil : id
    }

    /// Lets go of the selected cut.
    func closeTransitions() {
        selectedJoinID = nil
    }

    /// How the selected cut plays: a hard cut ("None"), a dissolve or a fade. An undo step; the
    /// playhead goes a moment before the cut so Play shows it.
    func setTransition(_ transition: EditTransition) {
        guard let index = selectedJoinIndex else { return }
        setTransition(transition, atJoin: index)
    }

    /// Sets the transition of the cut before the section at `index` (the Transitions tool lists
    /// every cut). An undo step; the playhead goes a moment before the cut so Play shows it.
    func setTransition(_ transition: EditTransition, atJoin index: Int) {
        guard isReady else { return }
        var timeline = edit.timeline
        guard timeline.setTransition(transition, atJoin: index) else { return }
        commit(timeline)
        if transition != .hardCut {
            player.pause()
            player.seek(to: max(0, edit.timeline.editedStart(ofSegmentAt: index) - Self.transitionLeadIn))
        }
    }

    /// The same transition on every cut, in one undo step.
    func setTransitionOnEveryCut(_ transition: EditTransition) {
        guard isReady else { return }
        var timeline = edit.timeline
        var changed = false
        for index in timeline.segments.indices.dropFirst() where timeline.setTransition(transition, atJoin: index) {
            changed = true
        }
        guard changed else { return }
        commit(timeline)
        toast.show(transition == .hardCut
            ? String(localized: "Every cut is a hard cut")
            : String(localized: "\(transition.label) on every cut"))
    }

    /// Edited seconds of every cut, by the index of the section after it.
    var cuts: [(index: Int, time: TimeInterval)] {
        edit.timeline.segments.indices.dropFirst().map { ($0, edit.timeline.editedStart(ofSegmentAt: $0)) }
    }

    // MARK: - Trim

    func beginTrim(_ handle: TrimHandle) {
        guard isReady else { return }
        endTrim()
        trimOrigin = edit.timeline
        activeHandle = handle
        removalRange = nil
        selectedSegmentID = nil
        selectedJoinID = nil
        player.pause()
    }

    /// Moves a handle to `time` (seconds of the recording) while it's dragged; the playhead and
    /// the preview follow it. Cuts don't stop it: the sections it passes leave the edit, and come
    /// back if it goes back before the finger lifts.
    func trim(_ handle: TrimHandle, toSource time: TimeInterval) {
        guard activeHandle == handle, let origin = trimOrigin else { return }
        var timeline = origin
        switch handle {
        case .start: timeline.trimStart(to: time)
        case .end: timeline.trimEnd(to: time)
        }
        if timeline != edit.timeline { edit.timeline = timeline }
        player.scrub(to: handle == .start ? 0 : timeline.editedDuration)
    }

    func endTrim() {
        guard let origin = trimOrigin else { return }
        trimOrigin = nil
        activeHandle = nil
        if origin != edit.timeline {
            var before = snapshot
            before.timeline = origin
            recordUndoStep(before)
        }
        player.endScrub()
    }

    /// VoiceOver: moves a handle by `seconds`.
    func nudgeTrim(_ handle: TrimHandle, by seconds: TimeInterval) {
        beginTrim(handle)
        let from = handle == .start ? edit.timeline.trimStart : edit.timeline.trimEnd
        trim(handle, toSource: from + seconds)
        endTrim()
    }

    // MARK: - Remove part

    /// Shows the red range around the playhead, two seconds long, to drag over what should go.
    func startRemovingPart() {
        guard isReady else { return }
        player.pause()
        let length = edit.editedDuration
        let start = max(0, min(length - Self.initialRemoval, player.currentTime - 1))
        removalRange = start...min(length, start + Self.initialRemoval)
        selectedSegmentID = nil
        selectedJoinID = nil
    }

    /// Moves an edge of the red range to `time` (edited seconds); the preview shows that frame.
    func moveRemovalEdge(_ edge: RemovalEdge, toEdited time: TimeInterval) {
        guard let range = removalRange else { return }
        let length = edit.editedDuration
        let moved: ClosedRange<TimeInterval>
        switch edge {
        case .start:
            let start = max(0, min(time, range.upperBound - Self.minimumRemoval))
            moved = start...range.upperBound
        case .end:
            let end = min(length, max(time, range.lowerBound + Self.minimumRemoval))
            moved = range.lowerBound...end
        }
        removalRange = moved
        player.scrub(to: edge == .start ? moved.lowerBound : moved.upperBound)
    }

    func cancelRemovingPart() {
        removalRange = nil
    }

    /// "Remove 00:02.10": takes the red range out (two cuts and a delete, one undo step).
    func removePart() {
        guard isReady, let range = removalRange else { return }
        var timeline = edit.timeline
        guard timeline.removeEdited(range) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        removalRange = nil
        commit(timeline)
        player.seek(to: range.lowerBound)
        toast.show(String(localized: "Removed \(DurationText.timecode(range.upperBound - range.lowerBound, total: edit.sourceDuration))"))
    }

    /// "00:02.10": how much the red range takes out.
    var removalLengthLabel: String {
        guard let range = removalRange else { return "" }
        return DurationText.timecode(range.upperBound - range.lowerBound, total: edit.editedDuration)
    }

    // MARK: - Cut and delete

    /// Cuts the section under the playhead in two and selects the second half, ready for Delete.
    func cut() {
        guard isReady else { return }
        let time = player.currentTime
        var timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: time)
        guard timeline.split(atEdited: time) else {
            toast.show(String(localized: "Move the playhead away from the edge"))
            return
        }
        removalRange = nil
        selectedJoinID = nil
        commit(timeline)
        selectedSegmentID = edit.timeline.segments[index + 1].id
        toast.show(String(localized: "Cut at \(DurationText.timecode(time, total: edit.editedDuration)) — tap a side, then Delete"))
    }

    /// Takes the selected section out of the edit.
    func removeSelection() {
        guard isReady else { return }
        guard let id = selectedSegmentID else {
            toast.show(String(localized: "Tap a section first"))
            return
        }
        var timeline = edit.timeline
        guard timeline.removeSegment(id: id) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        selectedSegmentID = nil
        commit(timeline)
        toast.show(String(localized: "Section deleted"))
    }
}
