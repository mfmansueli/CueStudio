//
//  OverlaysViewModel+Preview.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Editing right on the preview: tap a text to pick it (again: Text style opens), drag it (with
/// guides through the middle and the platform's safe area showing), pinch and turn it or drag its corner
/// (`+TextTransform`), ✕ to delete it. The caption on the preview is the Captions part's (`CaptionsViewModel+Preview`).
extension OverlaysViewModel {
    /// A text or the caption sticks to the middle within this share of the frame.
    static let centerSnap: Double = 0.025

    // MARK: - Texts

    /// A tap on a text in the preview: picks it (a locked one says so, with Unlock); a second tap opens Text style with the
    /// keyboard on its words, ready to fix one (the way CapCut's double tap does).
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
        sayIfLocked(.text(id))
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

    /// The text `factor` times as big (or its keyframe at the playhead, with keyframes), where it is and as it's turned: what
    /// VoiceOver's Bigger and Smaller do, the same change as a pinch.
    func scaleText(_ id: UUID, factor: Double) {
        guard let text = edit.texts.first(where: { $0.id == id }) else { return }
        let center = text.keyframes.isEmpty ? text.center : motionState(of: .text(id)).center
        transformText(id, center: center, factor: factor, rotation: text.graphic.map(\.rotation) ?? rotation(ofText: text))
    }

    // MARK: - Safe area

    /// The platform's safe area on a preview of `size`: what shows dashed while a text moves.
    func safeArea(in size: CGSize) -> CGRect {
        let unit = (edit.captionCollection?.safeMargins ?? CaptionsViewModel.captionSafeMargins(for: take, aspect: edit.aspect)).unitContentRect
        return CGRect(x: unit.minX * size.width, y: unit.minY * size.height, width: unit.width * size.width, height: unit.height * size.height)
    }
}
