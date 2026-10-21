//
//  QuickEditViewModel+Transitions.swift
//  Cue Studio
//

import Foundation

/// The cuts between clips and their transitions. Each change is one undo step.
extension QuickEditViewModel {
    // MARK: - Transitions

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

    /// How long the selected cut's transition lasts.
    var selectedTransitionDuration: TimeInterval? {
        guard let index = selectedJoinIndex, let transition = selectedTransition, transition != .hardCut else { return nil }
        return edit.timeline.segments[index].transitionDuration ?? transition.duration
    }

    /// The selected cut's transition `seconds` long (a drag of the slider is one undo step). When a clip next to it is too short,
    /// it plays shorter.
    func setTransitionDuration(_ seconds: TimeInterval) {
        guard isReady, let index = selectedJoinIndex else { return }
        let clamped = min(max(seconds, EditTransition.durationRange.lowerBound), EditTransition.durationRange.upperBound)
        var timeline = edit.timeline
        guard timeline.setTransitionDuration(clamped, atJoin: index) else { return }
        commit(timeline, key: "transitionDuration.\(index)")
    }

    /// The same transition on every cut, as long as the picked cut's, in one undo step. Already everywhere: a toast says so.
    func setTransitionOnEveryCut(_ transition: EditTransition) {
        guard isReady else { return }
        let duration = selectedJoinIndex.flatMap { edit.timeline.segments[$0].transitionDuration }
        var timeline = edit.timeline
        var changed = false
        for index in timeline.segments.indices.dropFirst() {
            if timeline.setTransition(transition, atJoin: index) { changed = true }
            if transition != .hardCut, timeline.setTransitionDuration(duration, atJoin: index) { changed = true }
        }
        guard changed else {
            toast.show(String(localized: "Every cut already has it"))
            return
        }
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
}
