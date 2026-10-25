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
            var main = settings
            // The same goes for the style's own way of showing words: a translation is shown whole.
            if case .translation = edit.captionDisplay { main = main.shownWhole }
            // "On the seam": the lines said while a support shows sit on the split screen's seam; the others where they are.
            let seams = seamSpans(of: edit)
            let onSeam = shown.main.filter { line in seams.contains { $0.span.contains(line.start) } }
            var overlays = CaptionCollectionRenderer.overlays(
                onSeam.isEmpty ? shown.main : shown.main.filter { line in !seams.contains { $0.span.contains(line.start) } },
                settings: main, position: edit.captionPosition, frame: frame, animation: animation
            )
            for seam in Set(seams.map(\.y)) {
                let lines = onSeam.filter { line in seams.contains { $0.y == seam && $0.span.contains(line.start) } }
                guard !lines.isEmpty else { continue }
                var placed = main
                placed.center = OverlayPoint(x: main.center?.x ?? 0.5, y: seam)
                overlays += CaptionCollectionRenderer.overlays(lines, settings: placed, position: edit.captionPosition, frame: frame, animation: animation)
            }
            var secondary = settings.shownWhole
            secondary.sizeScale *= 0.8
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

    /// Where the captions sit on the seam (`SplitScreen.captionsOnSeam`): each support's pieces with its layout's seam, as a
    /// fraction of the frame from the top. None side by side (the seam runs down the frame) or with the option off.
    static func seamSpans(of edit: TakeEdit) -> [(span: TimeSpan, y: Double)] {
        edit.splitScreen.captionsOnSeam ? splitSeams(of: edit) : []
    }

    /// Every seam across the frame while a split screen shows, option on or off: where a dragged caption sticks.
    static func splitSeams(of edit: TakeEdit) -> [(span: TimeSpan, y: Double)] {
        edit.placedMedia(in: edit.timeline).flatMap { entry -> [(span: TimeSpan, y: Double)] in
            guard entry.media.layout == .split else { return [] }
            let layout = edit.splitScreen.layout(id: entry.media.splitLayoutID)
            guard layout.arrangement == .stacked else { return [] }
            return entry.pieces.map { ($0.edited, SplitPlacement.seam(layout)) }
        }
    }
}
