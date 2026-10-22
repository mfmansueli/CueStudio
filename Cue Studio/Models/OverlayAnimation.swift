//
//  OverlayAnimation.swift
//  Cue Studio
//

import Foundation

/// A preset's motion on a text or a photo or video: which preset, how long it takes and how strong it is. It is laid over
/// the item's own place and keyframes (they stay the creator's to edit), so moving the item takes its animation along. Pure:
/// the preview, the export and the tests read the same motion (`OverlayMotion`).
nonisolated struct OverlayAnimation: Codable, Hashable, Sendable {
    static let durationRange: ClosedRange<TimeInterval> = 0.2...1.5
    static let intensityRange: ClosedRange<Double> = 0...1

    var preset: MotionPreset
    /// Seconds the entrance (and the exit, for In and out) takes.
    var duration: TimeInterval = 0.5
    /// 0 to 1: how far it travels, how much it grows.
    var intensity = 0.5

    init(preset: MotionPreset, duration: TimeInterval = 0.5, intensity: Double = 0.5) {
        self.preset = preset
        self.duration = min(max(duration, Self.durationRange.lowerBound), Self.durationRange.upperBound)
        self.intensity = min(max(intensity, Self.intensityRange.lowerBound), Self.intensityRange.upperBound)
    }

    /// What it changes `time` seconds into an item that shows for `length` seconds: a shift (fractions of the frame), a scale
    /// and an opacity, applied over where the item is.
    func modifier(at time: TimeInterval, length: TimeInterval) -> (dx: Double, dy: Double, scale: Double, opacity: Double) {
        let entrance = min(duration, max(0.05, length / 2))
        let into = min(max(time / entrance, 0), 1)
        let eased = into * into * (3 - 2 * into)
        let travel = 0.03 + 0.12 * intensity
        switch preset {
        case .fade:
            return (0, 0, 1, eased)
        case .slideUp:
            return (0, travel * (1 - eased), 1, eased)
        case .slideIn:
            return (-(travel + 0.05) * (1 - eased), 0, 1, eased)
        case .gentleZoom:
            let progress = length > 0 ? min(max(time / length, 0), 1) : 1
            return (0, 0, 1 + (0.04 + 0.16 * intensity) * progress, 1)
        case .pop:
            let start = 0.75 - 0.35 * intensity
            return (0, 0, PopEase.scale(from: start, elapsed: time, duration: entrance), min(1, into * 2))
        case .inAndOut:
            let out = min(max((length - time) / entrance, 0), 1)
            let outEased = out * out * (3 - 2 * out)
            return (0, travel * 0.6 * (1 - eased), 1, min(eased, outEased))
        }
    }
}
