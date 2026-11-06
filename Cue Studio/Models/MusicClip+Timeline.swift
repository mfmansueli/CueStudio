//
//  MusicClip+Timeline.swift
//  Cue Studio
//

import Foundation

nonisolated extension MusicClip {
    /// The clips after the timeline changed from `old` to `new`: a sound effect or an extracted sound follows the moment of
    /// the video it was put on (a cut before it brings it earlier, a moved clip takes it along), like texts and captions do;
    /// music keeps its place in the edit (it plays under the whole video, and the creator places it by ear).
    static func following(_ clips: [MusicClip], from old: EditTimeline, to new: EditTimeline) -> [MusicClip] {
        clips.map { clip in
            guard clip.followsTheVideo else { return clip }
            var moved = clip
            let start = new.editedTime(matching: clip.start, in: old)
            moved.start = min(max(0, start), max(0, new.editedDuration - min(clip.length, new.editedDuration)))
            return moved
        }
    }

    /// The music (not effects or extracted sounds, which follow the video on their own) that starts at `time` or later, in an
    /// edit `duration` long: what a clip put in at `time` moved away from (Insert in sequence leaves music where it is, and
    /// offers to move it along).
    static func music(startingFrom time: TimeInterval, in clips: [MusicClip], duration: TimeInterval) -> [MusicClip] {
        clips.filter { $0.takesMusicRoom && $0.start >= time - 0.05 && $0.start < duration - 0.05 }
    }

    /// The clips with the music that starts at `time` or later moved `seconds` later: along with a clip put in at `time`.
    static func moved(_ clips: [MusicClip], startingFrom time: TimeInterval, in duration: TimeInterval, by seconds: TimeInterval) -> [MusicClip] {
        let moving = Set(music(startingFrom: time, in: clips, duration: duration).map(\.id))
        return clips.map { clip in
            guard moving.contains(clip.id) else { return clip }
            var moved = clip
            moved.start += seconds
            return moved
        }
    }
}
