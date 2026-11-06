//
//  TakeEdit+ClipRemoval.swift
//  Cue Studio
//

import Foundation

nonisolated extension TakeEdit {
    /// The edit with the clip `id` deleted (never the recording), and what went with it; nil when it is the only clip or there is
    /// no such clip. One rule for a video of one take and a montage:
    ///
    /// - What was partly on it keeps the rest (`CutFollowing`): a text or a photo over it and the next clip stays on the next one.
    /// - What showed only on it goes with it: texts, photos and videos (in a video of one take they stay pinned to its seconds,
    ///   hidden, and show again if a handle brings those seconds back; in a montage they leave the edit, as nothing can bring the
    ///   clip back but Undo), and the sound effects and extracted sounds put on its moments (never onto the next clip, where they
    ///   would pile up).
    /// - A voice-over that started on it plays whole from where the edit picks up, never in another recording's seconds; one with
    ///   nothing left after it goes too.
    /// - Music stays where it is in the edit (kept in view at the end when the video got shorter than where it starts).
    func removingClip(_ id: UUID) -> ClipRemoval? {
        let old = timeline
        var shorter = old
        guard shorter.removeSegment(id: id) else { return nil }
        let before = EditSnapshot(self)
        var step = before
        step.timeline = shorter
        let followed = step.followingCuts(from: before, current: before)
        var next = self
        next.timeline = shorter
        next.texts = followed.texts
        next.media = followed.media
        next.voiceOvers = followed.voiceOvers
        next.music = followed.music ?? music
        var removal = ClipRemoval(edit: next)
        let arranged = shorter.isArranged
        /// Whether something shown over `was` (edited seconds before) shows `now` (as it is pinned after) and plays any of the
        /// same moments.
        func isGone(_ was: TimeSpan?, now: TimeSpan?) -> Bool {
            guard let was else { return false }
            return arranged ? CutFollowing.kept(was, from: old, to: shorter) == nil : now == nil
        }

        let goneTexts = Set(next.texts.filter { text in
            let was = texts.first { $0.id == text.id }.flatMap { Self.editedSpan($0.span, anchor: $0.clipAnchor, in: old) }
            return !text.isEmpty && isGone(was, now: Self.editedSpan(text.span, anchor: text.clipAnchor, in: shorter))
        }.map(\.id))
        removal.texts = goneTexts.count

        let goneMedia = next.media.filter { item in
            isGone(media.first { $0.id == item.id }?.editedSpan(in: old), now: item.editedSpan(in: shorter))
        }
        removal.photos = goneMedia.filter { $0.kind == .photo }.count
        removal.videos = goneMedia.count - removal.photos

        let goneVoices = Set(next.voiceOvers.filter { voice in
            let was = voiceOvers.first { $0.id == voice.id }?.editedSpan(in: old).map { TimeSpan(start: $0.start, end: old.editedDuration) }
            return isGone(was, now: voice.editedSpan(in: shorter))
        }.map(\.id))
        removal.voiceOvers = goneVoices.count

        // Sounds put on its moments: an effect is its moment, so one whose moment went goes with it.
        let goneSounds = Set(music.filter { clip in
            guard clip.followsTheVideo, clip.span(inEditOf: old.editedDuration) != nil else { return false }
            let moment = TimeSpan(start: clip.start, end: min(old.editedDuration, clip.start + 0.01))
            return CutFollowing.kept(moment, from: old, to: shorter) == nil
        }.map(\.id))
        removal.sounds = goneSounds.count
        removal.edit.music.removeAll { goneSounds.contains($0.id) }

        if arranged {
            let mediaIDs = Set(goneMedia.map(\.id))
            removal.edit.texts.removeAll { goneTexts.contains($0.id) }
            removal.edit.media.removeAll { mediaIDs.contains($0.id) }
            removal.edit.voiceOvers.removeAll { goneVoices.contains($0.id) }
        }
        return removal
    }
}
