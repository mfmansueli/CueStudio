//
//  QuickEditViewModel+LayerReset.swift
//  Cue Studio
//

import Foundation

/// Reset in the panels of what lies on the video (owner, canvas 2 R5, 07/11/2026: only these, each with a defined reach). Each puts
/// back only what its panel sets, in one undo step, and shows only once that differs from how the item came in:
/// - **Text** (one text): its look as a new text of its role starts on this video (`OverlaysViewModel.startingText`) and no
///   motion; its words, place, time and turn stay.
/// - **Graphic**: its kind's color, size 100%, no turn and no motion; its words (a tag's) and place stay.
/// - **Motion** (a photo or video): no entrance or exit and no keyframes; its time stays.
/// - **Photo or video**: the window's ratio Original, its size and opacity as it came in; how it shows (full screen, window), the
///   part of a video that plays and its place among the others stay (they change its length or the layout, not a setting).
extension QuickEditViewModel {
    var textReset: (() -> Void)? {
        guard overlays.textStyleScope == .selected, let text = selectedText else { return nil }
        let reset = text.graphic == nil ? textAsItStarts(text) : graphicAsItStarts(text)
        guard reset != text else { return nil }
        return { [weak self] in self?.overlays.updateText(text.id) { $0 = reset } }
    }

    var motionReset: (() -> Void)? {
        guard let media = selectedMedia, media.animation != nil || !(media.keyframes ?? []).isEmpty else { return nil }
        return { [weak self] in
            self?.overlays.updateMedia(media.id) {
                $0.animation = nil
                $0.keyframes = nil
            }
        }
    }

    var mediaReset: (() -> Void)? {
        guard let media = selectedMedia, media.layout != .split else { return nil }
        let fresh = MediaOverlay(kind: media.kind, fileName: media.fileName, aspect: media.aspect, mediaDuration: media.mediaDuration, span: media.span)
        guard media.shape != fresh.shape || media.width != fresh.width || media.opacity != nil else { return nil }
        return { [weak self] in
            self?.overlays.updateMedia(media.id) {
                $0.shape = fresh.shape
                $0.width = fresh.width
                $0.opacity = nil
            }
        }
    }

    /// `text` wearing the look a new text of its role starts with, with no motion.
    private func textAsItStarts(_ text: TextOverlay) -> TextOverlay {
        let fresh = overlays.startingText(text.role, span: text.span)
        var reset = text
        reset.font = fresh.font
        reset.weight = fresh.weight
        reset.size = fresh.size
        reset.tracking = fresh.tracking
        reset.isUppercase = fresh.isUppercase
        reset.alignment = fresh.alignment
        reset.color = fresh.color
        reset.background = fresh.background
        reset.backgroundColor = fresh.backgroundColor
        reset.backgroundOpacity = fresh.backgroundOpacity
        reset.hasShadow = fresh.hasShadow
        reset.hasOutline = fresh.hasOutline
        reset.glow = fresh.glow
        reset.effect = fresh.effect
        reset.lettering = fresh.lettering
        reset.preset = fresh.preset
        reset.customized = []
        reset.animation = nil
        reset.keyframes = []
        return reset
    }

    /// A graphic as `OverlaysViewModel.addGraphic` puts it on the video, where it is now.
    private func graphicAsItStarts(_ text: TextOverlay) -> TextOverlay {
        guard let kind = text.graphic?.kind else { return text }
        var reset = text
        reset.color = kind.defaultColor
        reset.size = TextGraphic.baseSize
        reset.graphic?.rotation = 0
        reset.animation = nil
        reset.keyframes = []
        return reset
    }
}
