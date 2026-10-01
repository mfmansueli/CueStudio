//
//  EditedComposition+Captions.swift
//  Cue Studio
//

import CoreGraphics

nonisolated extension EditedComposition {
    static func captionOverlays(for edit: TakeEdit, frame: CGSize) -> [FrameOverlay] {
        let shown = edit.shownCaptions
        if let settings = edit.captionCollection {
            // Translated words aren't timed to the voice: they show whole.
            let animation: CaptionAnimation = if case .translation = edit.captionDisplay { .line } else { edit.captionAnimation }
            var overlays = CaptionCollectionRenderer.overlays(
                shown.main, settings: settings, position: edit.captionPosition, frame: frame, animation: animation
            )
            var secondary = settings
            secondary.sizeScale *= 0.8
            secondary.followsWords = false
            let y = settings.center?.y ?? edit.captionPosition.verticalFraction
            secondary.center = OverlayPoint(x: settings.center?.x ?? 0.5, y: y + (y < 0.5 ? 0.12 : -0.12))
            overlays += CaptionCollectionRenderer.overlays(shown.second, settings: secondary, position: edit.captionPosition, frame: frame)
            return overlays
        }
        if let look = edit.captionLook {
            // Translated words aren't timed to the voice, so old word effects stay static too.
            let mainAnimation: CaptionAnimation = if case .translation = edit.captionDisplay {
                edit.captionAnimation == .fade ? .fade : .line
            } else {
                edit.captionAnimation
            }
            return TextOverlayRenderer.captions(shown.main, look: look, position: edit.captionPosition, frame: frame, animation: mainAnimation)
                + TextOverlayRenderer.secondCaptions(shown.second, look: look, position: edit.captionPosition, frame: frame)
        }
        return OverlayRenderer.captions(shown.main, style: edit.captionStyle, position: edit.captionPosition, frame: frame)
            + TextOverlayRenderer.secondCaptions(shown.second, look: TypePreset.cue.look(for: .caption), position: edit.captionPosition, frame: frame)
    }
}
