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

    /// Whether the word being said can be seen lit: lit only in a color, that color isn't the words' own (a box or a pop show
    /// anyway).
    var captionHighlightStandsOut: Bool {
        guard let settings = edit.captionCollection, captionMotion.spoken == .color else { return true }
        let spec = settings.spec
        let accent = settings.highlightColor.components
        let text = spec.textColor
        let distance = ((accent.red - text.red) * (accent.red - text.red) + (accent.green - text.green) * (accent.green - text.green)
            + (accent.blue - text.blue) * (accent.blue - text.blue)).squareRoot()
        return distance >= 0.3
    }

    /// Word by word adds nothing when each block is one word (Format › One word).
    var captionRevealIsMoot: Bool { edit.captionCollection?.format == .oneWord }

    private func changeCaptionMotion(_ update: (inout CaptionMotion) -> Void) {
        guard isReady, edit.captionCollection != nil else { return }
        let current = captionMotion
        var motion = current
        update(&motion)
        // The choice already showing changes nothing (an edit from before motion keeps drawing as it was).
        guard motion != current else { return }
        let aspect = edit.aspect
        change { snapshot in
            guard let before = snapshot.captionCollection else { return }
            // Motion is drawn by the collection: a look an earlier version copied goes as changes over the style.
            var settings = before.withoutCopiedLook
            settings.motion = motion
            settings.followsWords = motion.followsWords
            snapshot.captionCollection = settings
            snapshot.captionAnimation = motion.nearestAnimation
            // A pop leaves room between words: the lines of a format are cut again for it.
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        previewCurrentCaptionLine()
    }
}
