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
        guard index > 0, edit.timeline.segments.indices.contains(index) else { return }
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

    /// Under the transitions: a cut that removed nothing shows both sides as the same video.
    var transitionNote: String? {
        guard let index = selectedJoinIndex else { return nil }
        let timeline = edit.timeline
        let transition = timeline.transition(atJoin: index)
        if transition.showsBothSides, timeline.continuesFromPrevious(index) {
            return String(localized: "Nothing was cut out here, so \(transition.label) won't show")
        }
        return nil
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

    // MARK: - Cut and delete

    /// Cuts the section under the playhead in two and selects the second half, ready for Delete.
    func cut() {
        guard isReady else { return }
        let time = player.currentTime
        var timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: time)
        guard timeline.split(atEdited: time) else {
            toast.show(String(localized: "Move playhead off the edge"))
            return
        }
        selectedJoinID = nil
        commit(timeline)
        selectedSegmentID = edit.timeline.segments[index + 1].id
        toast.show(String(localized: "Cut at \(DurationText.timecode(time, total: edit.editedDuration)) · Tap a side"))
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
