//
//  PlatformPreset.swift
//  Cue Studio
//

import Foundation

/// Everything a destination sets up: capture settings, length goals, where the Selfie prompter sits
/// and which parts of the frame the platform covers. Built from `PlatformRules`, never by hand.
nonisolated struct PlatformPreset: Hashable, Sendable {
    var aspect: AspectRatio
    var resolution: VideoResolution
    var frameRate: FrameRate
    /// Length range that performs best on the platform.
    var idealRange: ClosedRange<TimeInterval>
    /// Minimum length to earn money; only set when monetization goals are on.
    var minimum: TimeInterval?
    var goal: MonetizationGoal?
    /// Long-form content is usually read on a rig, so Studio mode becomes the primary action.
    var prefersStudio: Bool
    var prompter: PrompterPanelLayout
    /// Parts of the frame covered by the platform's buttons and captions.
    var safeZones: [SafeZone]

    var showsSafeZones: Bool { !safeZones.isEmpty }

    /// "9:16 · 1080p30"
    var captureSummary: String {
        "\(aspect.label) · \(resolution.label)\(frameRate.rawValue)"
    }

    /// "9:16 · 1080p30 · safe zones · ideal 1:00–1:30"
    var summary: String {
        let ideal = DurationText.clock(idealRange.lowerBound) + "–" + DurationText.clock(idealRange.upperBound)
        let zones = showsSafeZones ? " · " + String(localized: "safe zones") : ""
        return captureSummary + zones + " · " + String(localized: "ideal \(ideal)")
    }
}
