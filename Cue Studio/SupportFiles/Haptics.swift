//
//  Haptics.swift
//  Cue Studio
//

import UIKit

/// The editor's haptics, one per meaning, so every screen feels the same: picking and snapping
/// (selection), applying a panel (light), deleting (rigid), starting and stopping a voice-over
/// (medium). The system skips them where there is no Taptic Engine (and in tests).
@MainActor
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// Something was picked.
    static func selection() {
        selectionGenerator.selectionChanged()
    }

    /// The playhead or a handle landed on a cut, a line's edge or a keyframe.
    static func snap() {
        selectionGenerator.selectionChanged()
    }

    /// A panel's ✓.
    static func apply() {
        lightGenerator.impactOccurred()
    }

    static func delete() {
        rigidGenerator.impactOccurred()
    }

    /// A voice-over starts or stops recording.
    static func record() {
        mediumGenerator.impactOccurred()
    }
}
