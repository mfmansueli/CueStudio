//
//  MusicClip+Timeline.swift
//  Cue Studio
//

import Foundation

nonisolated extension MusicClip {
    /// The clips after the timeline changed from `old` to `new`: a sound effect follows the moment of the video it was put on
    /// (a cut before it brings it earlier, a moved clip takes it along), like texts and captions do; music keeps its place in
    /// the edit (it plays under the whole video, and the creator places it by ear).
    static func following(_ clips: [MusicClip], from old: EditTimeline, to new: EditTimeline) -> [MusicClip] {
        clips.map { clip in
            guard clip.effect != nil else { return clip }
            var moved = clip
            let start = new.editedTime(matching: clip.start, in: old)
            moved.start = min(max(0, start), max(0, new.editedDuration - min(clip.length, new.editedDuration)))
            return moved
        }
    }
}
