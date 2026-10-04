//
//  Haptics.swift
//  Cue Studio
//

import UIKit

/// The app's haptics, one per meaning, so every screen feels the same: picking and snapping
/// (selection), applying a panel (light), deleting (rigid), starting and stopping a recording
/// (medium), something arriving (success). The system skips them where there is no Taptic Engine
/// (and in tests). Settings › Personalize › Haptics turns all of them off (`isEnabled`).
@MainActor
enum Haptics {
    /// Settings › Personalize › Haptics. `PersonalizationService` keeps it in step.
    static var isEnabled = true

    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Something was picked: a topic, a platform, a tab, a step of a slider.
    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    /// The playhead or a handle landed on a cut, a line's edge or a keyframe.
    static func snap() {
        selection()
    }

    /// An orb reached an end of its rail, or Cue picked the best take.
    static func soft() {
        guard isEnabled else { return }
        softGenerator.impactOccurred()
    }

    /// A panel's ✓, or one of the 3·2·1.
    static func apply() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
    }

    static func delete() {
        guard isEnabled else { return }
        rigidGenerator.impactOccurred()
    }

    /// A recording or voice-over starts or stops, or "Let's Cue" ends the countdown.
    static func record() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    /// A world is born, a video arrives, the first star, a milestone, a permission granted.
    static func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }
}
