//
//  CaptionsViewModel+Adjust.swift
//  Cue Studio
//

import Foundation

/// Caption style › Adjust: the same controls over any look (one of Cue's styles, a saved one, a text's look copied onto the
/// captions): family, weight, case, text color, background, outline, shadow, letter spacing and how the marked words stand
/// out. Each change is one undo step (a slider's drag is one), kept over the style until another style is picked or "Back to
/// the style's look" brings the style back whole (with its highlight color and motion). A look copied by an earlier version
/// turns into changes over its style at the first one.
extension CaptionsViewModel {
    /// What Adjust shows: the look the captions draw with now (copied looks read as their changes).
    var captionAdjustSettings: CaptionSettings? {
        edit.captionCollection.map(\.withoutCopiedLook)
    }

    /// How many parts of the look are changed ("· N changed"); 0 for the style's own.
    var changedCaptionLookCount: Int {
        captionAdjustSettings?.changedLookCount ?? 0
    }

    /// Changes the look over the style (one undo step; `key` makes a slider's drag one step).
    func adjustCaptions(key: String? = nil, _ update: (inout CaptionAdjustments) -> Void) {
        guard isReady, edit.captionCollection != nil else { return }
        let aspect = edit.aspect
        change(key: key) { snapshot in
            guard let before = snapshot.captionCollection else { return }
            var settings = before.withoutCopiedLook
            var adjustments = settings.adjustments ?? CaptionAdjustments()
            update(&adjustments)
            settings.adjustments = adjustments.isEmpty ? nil : adjustments
            snapshot.captionCollection = settings
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        checkCaptionContrast()
    }

    /// Draws the lines in `face` (nil: the style's own family); a weight it doesn't have goes back to the style's.
    func setCaptionFace(_ face: TextOverlayFont?) {
        guard isReady, let settings = edit.captionCollection, settings.withoutCopiedLook.face != face else { return }
        let aspect = edit.aspect
        change { snapshot in
            guard let before = snapshot.captionCollection else { return }
            var next = before.withoutCopiedLook
            next.face = face
            if let weight = next.adjustments?.weight, !next.availableWeights.contains(weight) { next.adjustments?.weight = nil }
            if next.adjustments?.isEmpty == true { next.adjustments = nil }
            snapshot.captionCollection = next
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        previewCurrentCaptionLine()
        checkCaptionContrast()
    }

    /// "Back to <style>'s look" (Adjust and Animation): the style whole again, as its card shows it, in one undo step. The
    /// family, every change over it, the highlight color and how it moves go; where it sits, how big, how wide and how it is
    /// cut stay (Format).
    func resetCaptionLook() {
        guard isReady, changedCaptionLookCount > 0 else { return }
        let aspect = edit.aspect
        change { snapshot in
            guard let before = snapshot.captionCollection else { return }
            var next = before.withoutCopiedLook
            next.face = nil
            next.adjustments = nil
            next.accent = nil
            if next.movesItsOwnWay {
                let style = next.styleSpec
                next.motion = style.motion
                next.followsWords = style.motion?.followsWords ?? style.animation.followsWords
                snapshot.captionAnimation = style.motion?.nearestAnimation ?? style.animation
            }
            snapshot.captionCollection = next
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        previewCurrentCaptionLine()
        checkCaptionContrast()
    }

    /// Measures the look as it is over a white picture, the brightest a video gives it, and warns when the words would be
    /// hard to read there (`CaptionContrastProbe`).
    func checkCaptionContrast() {
        guard let settings = captionAdjustSettings else {
            captionContrastWarning = false
            return
        }
        let reading = CaptionContrastProbe.reading(settings, over: ColorContrast.RGB(red: 1, green: 1, blue: 1))
        captionContrastWarning = reading.map { $0.words < ColorContrast.textMinimum } ?? false
    }
}
