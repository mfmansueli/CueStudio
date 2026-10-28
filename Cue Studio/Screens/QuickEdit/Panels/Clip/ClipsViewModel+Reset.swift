//
//  ClipsViewModel+Reset.swift
//  Cue Studio
//

import Foundation

/// Reset clip (clip toolbar): the picked clip back as filmed in one undo step (`EditSegment.asRecorded`), playing forward if it
/// was reversed. Where it starts and ends, its place in the montage, the transition into it and everything laid over it stay. A
/// clip whose sound was taken out to a track (Extract audio) stays muted, or its sound would play twice.
extension ClipsViewModel {
    /// Whether Reset clip has anything to put back on the picked clip.
    var canResetClip: Bool {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return false }
        return asRecorded(clip, at: index) != clip || reversal(of: clip) != nil
    }

    func resetClip() {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
        let reset = asRecorded(clip, at: index)
        let reversal = reversal(of: clip)
        guard reset != clip || reversal != nil else {
            toast.show(String(localized: "This clip is already as filmed"), kind: .problem)
            return
        }
        player.pause()
        beginChange()
        var timeline = edit.timeline
        if timeline.replaceSegment(reset), timeline != edit.timeline { commit(timeline) }
        if let reversal { playForward(reset, at: index, from: reversal) }
        endChange()
        toast.show(String(localized: "Clip reset"), action: undoAction)
    }

    private func asRecorded(_ clip: EditSegment, at index: Int) -> EditSegment {
        clip.asRecorded(keepsMute: soundIsOnATrack(ofClipAt: index))
    }

    /// A sound taken out of a clip (Extract audio) plays where the clip at `index` does.
    private func soundIsOnATrack(ofClipAt index: Int) -> Bool {
        let timeline = edit.timeline
        let start = timeline.editedStart(ofSegmentAt: index)
        let end = start + timeline.segments[index].duration
        return edit.music.contains { music in
            guard music.extractedFrom == .clip, let span = music.span(inEditOf: timeline.editedDuration) else { return false }
            return span.start < end - 0.05 && span.end > start + 0.05
        }
    }
}
