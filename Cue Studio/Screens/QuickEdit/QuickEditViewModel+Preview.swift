//
//  QuickEditViewModel+Preview.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Editing right on the preview: tap a text to pick it (again: Text style opens), drag it (with
/// guides through the middle and the platform's safe area showing), drag its corner to scale it,
/// ✕ to delete it; drag the caption up or down to move every caption, sticking to top, middle and
/// bottom.
extension QuickEditViewModel {
    /// A text or the caption sticks to the middle within this share of the frame.
    static let centerSnap: Double = 0.025
    /// Where captions stick when dragged: top, middle and bottom.
    static let captionStops: [Double] = [0.16, 0.5, 0.76]
    /// Captions stick to a stop within this share of the frame.
    static let captionSnap: Double = 0.03
    /// How much the corner handle scales per point dragged (down and right grows).
    static let scalePerPoint: Double = 1.0 / 140

    // MARK: - Texts

    /// A tap on a text in the preview: picks it, or opens Text style when it was already picked.
    func tapText(_ id: UUID) {
        guard isReady else { return }
        player.pause()
        if selection == .text(id) {
            panel = .textStyle
            return
        }
        Haptics.selection()
        let keepsPanel = panel == .textStyle
        selection = .text(id)
        if !keepsPanel { panel = nil }
    }

    /// A text dragged to `center` (unit coordinates), stuck to the middle when close to it.
    static func snapped(_ center: OverlayPoint) -> (center: OverlayPoint, vertical: Bool, horizontal: Bool) {
        var point = center.clamped
        let vertical = abs(point.x - 0.5) < centerSnap
        let horizontal = abs(point.y - 0.5) < centerSnap
        if vertical { point.x = 0.5 }
        if horizontal { point.y = 0.5 }
        return (point, vertical, horizontal)
    }

    /// The corner handle dragged by `translation` (points): the text grows or shrinks; with
    /// keyframes, its keyframe at the playhead does.
    func scaleText(_ id: UUID, by translation: CGSize) {
        let factor = Self.scaleFactor(for: translation)
        guard let text = edit.texts.first(where: { $0.id == id }) else { return }
        if text.keyframes.isEmpty {
            let size = min(max(text.size * factor, TextOverlay.sizeRange.lowerBound), TextOverlay.sizeRange.upperBound)
            customizeText(id, .size) { $0.size = size }
        } else {
            let current = motionState(of: .text(id)).scale
            selection = .text(id)
            setKeyframeScale(current * factor)
        }
    }

    static func scaleFactor(for translation: CGSize) -> Double {
        min(max(1 + Double(translation.width + translation.height) * scalePerPoint, 0.4), 3)
    }

    // MARK: - Captions

    /// The caption showing at the playhead and its box on a preview of `size` (from the top left).
    func previewCaption(in size: CGSize) -> (id: UUID, frame: CGRect)? {
        guard edit.showsCaptions, size.width > 0 else { return nil }
        let time = player.currentTime
        guard let instance = edit.editedCaptionInstances.first(where: { $0.line.span.contains(time) }) else { return nil }
        var shown = edit
        // Only that line, measured the way the export draws it.
        shown.captions = edit.captions.filter { $0.id == instance.cueID }
        shown.captionTranslations = []
        let overlays = EditedComposition.captionOverlays(for: shown, frame: size)
        guard let overlay = overlays.first(where: { $0.span?.contains(time) ?? true }) ?? overlays.first else { return nil }
        let frame = CGRect(x: overlay.origin.x, y: size.height - overlay.origin.y - overlay.size.height, width: overlay.size.width, height: overlay.size.height)
        return (instance.cueID, frame)
    }

    /// A tap on the caption in the preview: picks its line, or opens Captions when it was picked.
    func tapCaption(_ id: UUID) {
        guard isReady else { return }
        player.pause()
        if selection == .caption(id) {
            panel = .captions
            return
        }
        Haptics.selection()
        let keepsPanel = panel == .captions || panel == .captionStyle
        selection = .caption(id)
        if !keepsPanel { panel = nil }
    }

    /// Where captions go when dragged to `y` (unit, from the top): stuck to top, middle or bottom
    /// when close.
    static func snappedCaption(_ y: Double) -> (y: Double, stop: Double?) {
        let clamped = min(max(y, 0.1), 0.9)
        if let stop = captionStops.first(where: { abs($0 - clamped) < captionSnap }) { return (stop, stop) }
        return (clamped, nil)
    }

    /// Every caption moves up or down to `y` (unit, from the top). One undo step.
    func moveCaptions(toY y: Double) {
        let placed = Self.snappedCaption(y).y
        if edit.captionCollection != nil {
            updateCaptionSettings { settings in
                settings.center = OverlayPoint(x: settings.center?.x ?? 0.5, y: placed)
            }
        } else {
            let nearest = CaptionPosition.allCases.min { abs($0.verticalFraction - placed) < abs($1.verticalFraction - placed) } ?? .bottom
            change { $0.captionPosition = nearest }
        }
    }

    /// The captions' height on the frame (unit, from the top).
    var captionY: Double {
        edit.captionCollection?.center?.y ?? edit.captionPosition.verticalFraction
    }

    // MARK: - Safe area

    /// The platform's safe area on a preview of `size`: what shows dashed while a text moves.
    func safeArea(in size: CGSize) -> CGRect {
        let unit = (edit.captionCollection?.safeMargins ?? captionSafeMargins).unitContentRect
        return CGRect(x: unit.minX * size.width, y: unit.minY * size.height, width: unit.width * size.width, height: unit.height * size.height)
    }
}
