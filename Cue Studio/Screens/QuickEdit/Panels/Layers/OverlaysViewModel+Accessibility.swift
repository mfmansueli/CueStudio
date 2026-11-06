//
//  OverlaysViewModel+Accessibility.swift
//  Cue Studio
//

import Accessibility
import Foundation

/// VoiceOver's way to place what lies on the video, where a finger drags, pinches and turns: a step up, down, left or right,
/// bigger or smaller, a text turned either way (the actions of a text's or a photo's handle), each an undo step, and where it
/// landed said aloud. A locked one stays and says so, as it does under a finger (`EditorPart+Lock`).
extension OverlaysViewModel {
    /// One step: a twentieth of the frame.
    static let overlayStep = 0.05
    /// Bigger or smaller by this much.
    static let overlayScaleStep = 1.1
    /// A text's turn: 15° at a time.
    static let rotationStep = 15 * Double.pi / 180

    func nudgeOverlay(_ item: MotionItem, x: Double, y: Double) {
        guard !refusesMoving(item.id) else { return }
        let center = motionState(of: item).center
        let moved = OverlayPoint(x: min(max(center.x + x, 0), 1), y: min(max(center.y + y, 0), 1))
        switch item {
        case .text(let id): moveText(id, to: moved)
        case .media(let id): moveMedia(id, to: moved)
        }
        AccessibilityNotification.Announcement(String(localized: "\(Int((moved.x * 100).rounded()))% across, \(Int((moved.y * 100).rounded()))% down")).post()
    }

    func resizeOverlay(_ item: MotionItem, bigger: Bool) {
        guard !refusesMoving(item.id) else { return }
        let factor = bigger ? Self.overlayScaleStep : 1 / Self.overlayScaleStep
        switch item {
        case .text(let id): scaleText(id, factor: factor)
        case .media(let id): resizeMedia(id, by: factor)
        }
        AccessibilityNotification.Announcement(bigger ? String(localized: "Bigger") : String(localized: "Smaller")).post()
    }

    /// A text turned a step clockwise or back, stuck to straight when it lands near it.
    func turnText(_ id: UUID, clockwise: Bool) {
        guard !refusesMoving(id), let text = edit.texts.first(where: { $0.id == id }) else { return }
        let now = text.graphic.map(\.rotation) ?? rotation(ofText: text)
        let turned = Self.snappedRotation(now + (clockwise ? Self.rotationStep : -Self.rotationStep)).rotation
        let center = text.keyframes.isEmpty ? text.center : motionState(of: .text(id)).center
        transformText(id, center: center, factor: 1, rotation: turned)
        let degrees = Int((Self.normalizedRotation(turned) * 180 / .pi).rounded())
        AccessibilityNotification.Announcement(String(localized: "Turned \(degrees)°", comment: "VoiceOver: a text's turn after Turn left or right")).post()
    }
}
