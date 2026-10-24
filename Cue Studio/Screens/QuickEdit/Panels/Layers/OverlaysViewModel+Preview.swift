//
//  OverlaysViewModel+Preview.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Editing right on the preview: tap a text to pick it (again: Text style opens), drag it (with
/// guides through the middle and the platform's safe area showing), drag its corner to scale it,
/// ✕ to delete it. The caption on the preview is the Captions part's (`CaptionsViewModel+Preview`).
extension OverlaysViewModel {
    /// A text or the caption sticks to the middle within this share of the frame.
    static let centerSnap: Double = 0.025
    /// How much the corner handle scales per point dragged (down and right grows).
    static let scalePerPoint: Double = 1.0 / 140

    // MARK: - Texts

    /// A tap on a text in the preview: picks it; a second tap opens Text style with the keyboard on its words, ready to fix
    /// one (the way CapCut's double tap does).
    func tapText(_ id: UUID) {
        guard isReady else { return }
        player.pause()
        if selection == .text(id) {
            panel = .textStyle
            focusesTextField = true
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
        scaleText(id, factor: Self.scaleFactor(for: translation))
    }

    /// The text `factor` times as big (or its keyframe at the playhead, with keyframes).
    func scaleText(_ id: UUID, factor: Double) {
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

    // MARK: - Safe area

    /// The platform's safe area on a preview of `size`: what shows dashed while a text moves.
    func safeArea(in size: CGSize) -> CGRect {
        let unit = (edit.captionCollection?.safeMargins ?? CaptionsViewModel.captionSafeMargins(for: take, aspect: edit.aspect)).unitContentRect
        return CGRect(x: unit.minX * size.width, y: unit.minY * size.height, width: unit.width * size.width, height: unit.height * size.height)
    }
}
