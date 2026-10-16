//
//  EditorMontage.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A montage with everything the editor added at once: a second recording brought in with a Zoom transition, a Flash back to
/// the take, a frozen frame, the part of a B-roll video from its second 2, an arrow sliding up, captions in the Bold hook
/// template and a sound effect. The preview-against-export test and the device timing build the same edit.
enum EditorMontage {
    /// The files it needs, made by the caller: the take, another recording, a B-roll video and a frozen frame (`StillClipWriter`).
    struct Files {
        let other: String
        let broll: String
        let still: String
        let sound: String?
    }

    /// 3 s of the take, 2 s of the other recording, 1 s frozen, then the take from 3 to 6 s: 9 s in all.
    static let duration: TimeInterval = 9

    static func edit(takeDuration: TimeInterval = 6, files: Files) -> TakeEdit {
        var edit = TakeEdit(sourceDuration: takeDuration, aspect: .portrait)
        edit.voiceEnhancement = .off
        let other = ClipSource(fileName: files.other, duration: 4, title: "Other")
        let still = ClipSource(fileName: files.still, duration: 5, title: "Freeze frame")
        edit.timeline.split(atEdited: 3)
        edit.timeline.insertClip(source: other.id, duration: 4, span: TimeSpan(start: 1, end: 3), at: 1)
        edit.timeline.insertClip(source: still.id, duration: 5, span: TimeSpan(start: 0, end: 1), at: 2)
        edit.timeline.setTransition(.zoom, atJoin: 1)
        edit.timeline.setTransitionDuration(0.6, atJoin: 1)
        edit.timeline.setTransition(.flash, atJoin: 3)
        edit.sources = [other, still]

        var broll = MediaOverlay(kind: .video, fileName: files.broll, aspect: 9.0 / 16, mediaDuration: 6, span: TimeSpan(start: 6.5, end: 8))
        broll.mediaStart = 2
        edit.media = [broll]

        var arrow = edit.newText(.callout, span: TimeSpan(start: 0.2, end: 2.6))
        arrow.graphic = TextGraphic(kind: .arrow)
        arrow.color = CoverItemKind.arrow.defaultColor
        arrow.size = TextGraphic.baseSize
        arrow.text = ""
        arrow.animation = OverlayAnimation(preset: .slideUp, duration: 0.5, intensity: 0.6)
        edit.texts = [arrow]

        let template = VideoTemplate.boldHook
        edit.captionCollection = template.captionSettings
        edit.captionAnimation = template.captionReveal
        edit.showsCaptions = true
        edit.captions = [
            CaptionCue(text: "Real talk about pizza", start: 0.3, end: 1.8),
            CaptionCue(text: "The crust matters most", start: 3.4, end: 4.9),
        ]
        if let sound = files.sound {
            let length = Double(SoundEffectSynth.samples(for: .whoosh).count) / SoundEffectSynth.sampleRate
            var clip = MusicClip(fileName: sound, title: "Whoosh", fileDuration: length, start: 2.6, length: length)
            clip.effect = .whoosh
            clip.fadeIn = 0
            clip.fadeOut = 0
            clip.ducksUnderVoice = false
            edit.music = [clip]
        }
        return edit
    }
}
