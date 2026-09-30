//
//  OverlayKeyframe.swift
//  Cue Studio
//

import Foundation

/// Where a text or a photo or video is at a moment of its own time: its center, its scale and how
/// opaque it is. Its time counts from when the item starts showing, so moving the item takes its
/// motion along; stretching or cutting it leaves the keyframes where they are in its own time
/// (those past its end wait, and come back if it grows again).
nonisolated struct OverlayKeyframe: Codable, Hashable, Identifiable, Sendable {
    static let scaleRange: ClosedRange<Double> = 0.2...4
    /// Keyframes closer than this are one: a frame at 30 fps.
    static let sameMoment: TimeInterval = 1.0 / 30

    var id = UUID()
    /// Seconds from the item's start in the edit.
    var time: TimeInterval
    var center: OverlayPoint
    /// Times the item's size.
    var scale: Double = 1
    var opacity: Double = 1
    var easing: KeyframeEasing = .smooth

    init(time: TimeInterval, center: OverlayPoint, scale: Double = 1, opacity: Double = 1, easing: KeyframeEasing = .smooth) {
        self.time = max(0, time)
        self.center = center
        self.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        self.opacity = min(max(opacity, 0), 1)
        self.easing = easing
    }
}
