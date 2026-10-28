//
//  ClipsViewModel+Animation.swift
//  Cue Studio
//

import Foundation

/// Animation of the picked clip: how its picture comes in at its start (In) and goes out at its end (Out), a style and how long
/// it takes each (`ClipAnimation`). Picking one plays that end of the clip to show it, then the playhead comes back. Each change is
/// an undo step; a slider's quick moves are one.
extension ClipsViewModel {
    /// The picked clip's way in (`isIn`) or out.
    func clipAnimation(isIn: Bool) -> ClipAnimation? {
        isIn ? targetClip?.animationIn : targetClip?.animationOut
    }

    /// A style (nil: None) for the picked clip's way in or out, keeping how long it took.
    func setClipAnimation(_ style: ClipAnimationStyle?, isIn: Bool) {
        let duration = clipAnimation(isIn: isIn)?.duration ?? ClipAnimation.defaultDuration
        let animation = style.map { ClipAnimation(style: $0, duration: duration) }
        updateClip { clip in
            if isIn { clip.animationIn = animation } else { clip.animationOut = animation }
        }
        if animation != nil { previewClipAnimation(isIn: isIn) }
    }

    func setClipAnimationDuration(_ duration: TimeInterval, isIn: Bool) {
        guard var animation = clipAnimation(isIn: isIn) else { return }
        animation = ClipAnimation(style: animation.style, duration: duration)
        updateClip(key: isIn ? "clip.animationIn" : "clip.animationOut") { clip in
            if isIn { clip.animationIn = animation } else { clip.animationOut = animation }
        }
    }

    /// "Preview": the picked clip's start (In) or end (Out), its animation playing, a moment on either side, then the playhead
    /// comes back.
    func previewClipAnimation(isIn: Bool) {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id), let animation = clipAnimation(isIn: isIn) else { return }
        let start = edit.timeline.editedStart(ofSegmentAt: index)
        let end = start + clip.duration
        let span = min(clip.duration, animation.duration + Self.animationPreviewMargin)
        previewPart(isIn ? start...(start + span) : max(0, end - span)...end)
    }

    /// How much of the clip past its animation Preview plays.
    static let animationPreviewMargin: TimeInterval = 0.8

    // MARK: - The sound's fades

    /// The picked clip's sound rising from silence over its first `seconds`.
    func setClipSoundFadeIn(_ seconds: TimeInterval) {
        updateClip(key: "clip.soundFadeIn") { $0.soundFadeIn = EditSegment.clampedFade(seconds) }
    }

    /// The picked clip's sound falling to silence over its last `seconds`.
    func setClipSoundFadeOut(_ seconds: TimeInterval) {
        updateClip(key: "clip.soundFadeOut") { $0.soundFadeOut = EditSegment.clampedFade(seconds) }
    }
}
