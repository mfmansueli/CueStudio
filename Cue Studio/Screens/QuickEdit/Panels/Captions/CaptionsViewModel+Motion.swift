//
//  CaptionsViewModel+Motion.swift
//  Cue Studio
//

import Foundation

/// Caption style › Animation: how the captions come in and go out, whether they show whole or word by word, and how the word
/// being said stands out, three choices apart, each one undo step, the current line played to show it. Captions saved before
/// these choices show what they play, and take them at the first change.
extension CaptionsViewModel {
    /// How the captions move now (`CaptionMotion`); what an edit from before motion plays, read as the three choices.
    var captionMotion: CaptionMotion {
        guard let settings = edit.captionCollection else { return CaptionMotion() }
        if let motion = settings.motion { return motion }
        return CaptionMotion(playing: CaptionCollectionRenderer.effectiveAnimation(settings: settings, animation: edit.captionAnimation), spec: settings.spec)
    }

    func setCaptionEntry(_ entry: CaptionEntry) {
        changeCaptionMotion { $0.entry = entry }
    }

    func setCaptionRevealMode(_ reveal: CaptionReveal) {
        changeCaptionMotion { $0.reveal = reveal }
    }

    func setCaptionSpokenHighlight(_ spoken: CaptionSpokenHighlight) {
        changeCaptionMotion { $0.spoken = spoken }
    }

    /// Word by word adds nothing when each block is one word (Format › One word).
    var captionRevealIsMoot: Bool { edit.captionCollection?.format == .oneWord }

    private func changeCaptionMotion(_ update: (inout CaptionMotion) -> Void) {
        guard isReady, edit.captionCollection != nil else { return }
        var motion = captionMotion
        update(&motion)
        guard motion != edit.captionCollection?.motion else { return }
        change { snapshot in
            guard var settings = snapshot.captionCollection else { return }
            settings.motion = motion
            settings.followsWords = motion.followsWords
            snapshot.captionCollection = settings
            snapshot.captionAnimation = motion.nearestAnimation
        }
        previewCurrentCaptionLine()
    }
}
