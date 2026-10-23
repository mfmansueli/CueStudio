//
//  QuickEditViewModel+OverlayAccessibility.swift
//  Cue Studio
//

import Accessibility
import Foundation

/// VoiceOver's way to place what lies on the video, where a finger drags and pinches: a step up, down, left or right, bigger
/// or smaller (the actions of a text's or a photo's handle), each an undo step, and where it landed said aloud.
extension QuickEditViewModel {
    /// One step: a twentieth of the frame.
    static let overlayStep = 0.05
    /// Bigger or smaller by this much.
    static let overlayScaleStep = 1.1

    func nudgeOverlay(_ item: MotionItem, x: Double, y: Double) {
        let center = motionState(of: item).center
        let moved = OverlayPoint(x: min(max(center.x + x, 0), 1), y: min(max(center.y + y, 0), 1))
        switch item {
        case .text(let id): moveText(id, to: moved)
        case .media(let id): moveMedia(id, to: moved)
        }
        AccessibilityNotification.Announcement(String(localized: "\(Int((moved.x * 100).rounded()))% across, \(Int((moved.y * 100).rounded()))% down")).post()
    }

    func resizeOverlay(_ item: MotionItem, bigger: Bool) {
        let factor = bigger ? Self.overlayScaleStep : 1 / Self.overlayScaleStep
        switch item {
        case .text(let id): scaleText(id, factor: factor)
        case .media(let id): resizeMedia(id, by: factor)
        }
        AccessibilityNotification.Announcement(bigger ? String(localized: "Bigger") : String(localized: "Smaller")).post()
    }
}
