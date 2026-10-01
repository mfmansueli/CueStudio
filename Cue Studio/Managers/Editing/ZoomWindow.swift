//
//  ZoomWindow.swift
//  Cue Studio
//

import Foundation

/// A section's slow zoom where it plays in the edit.
nonisolated struct ZoomWindow: Hashable, Sendable {
    let zoom: SectionZoom
    /// Edited seconds where the section starts.
    let start: TimeInterval
    let duration: TimeInterval
    /// The clip's zoom strength, 0 to 1.
    var amount: Double = 0.5

    /// Times the frame's size at `time` (edited seconds).
    func scale(at time: TimeInterval) -> Double {
        zoom.scale(at: duration > 0 ? (time - start) / duration : 1, amount: amount)
    }
}
