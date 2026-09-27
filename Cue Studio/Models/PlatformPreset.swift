//
//  PlatformPreset.swift
//  Cue Studio
//

import Foundation

/// Capture settings and length goals for a destination. Platform rules change, so every number
/// lives here and nowhere else.
nonisolated struct PlatformPreset: Hashable, Sendable {
    var aspect: AspectRatio
    var resolution: VideoResolution
    var frameRate: FrameRate
    /// Length range that performs best on the platform.
    var idealRange: ClosedRange<TimeInterval>
    /// Minimum length to earn money; only set when monetization goals are on.
    var minimum: TimeInterval?
    var goal: MonetizationGoal?
    /// Whether the platform overlays buttons and captions that can cover the frame.
    var showsSafeZones: Bool
    /// Long-form content is usually read on a rig, so Studio mode becomes the primary action.
    var prefersStudio: Bool

    static func preset(for platform: Platform, monetizationGoals: Bool) -> PlatformPreset {
        switch platform {
        case .tiktok:
            PlatformPreset(
                aspect: .portrait, resolution: .hd1080, frameRate: .fps30,
                idealRange: monetizationGoals ? 60...90 : 15...60,
                minimum: monetizationGoals ? 60 : nil,
                goal: monetizationGoals ? .creatorRewards : nil,
                showsSafeZones: true, prefersStudio: false
            )
        case .reels:
            PlatformPreset(
                aspect: .portrait, resolution: .hd1080, frameRate: .fps30,
                idealRange: 15...60, minimum: nil, goal: nil,
                showsSafeZones: true, prefersStudio: false
            )
        case .shorts:
            PlatformPreset(
                aspect: .portrait, resolution: .hd1080, frameRate: .fps60,
                idealRange: 30...60, minimum: nil, goal: nil,
                showsSafeZones: true, prefersStudio: false
            )
        case .youtube:
            PlatformPreset(
                aspect: .landscape, resolution: .uhd4K, frameRate: .fps24,
                idealRange: monetizationGoals ? 480...900 : 240...600,
                minimum: monetizationGoals ? 480 : nil,
                goal: monetizationGoals ? .midRollAds : nil,
                showsSafeZones: false, prefersStudio: true
            )
        }
    }

    /// "9:16 · 1080p30"
    var captureSummary: String {
        "\(aspect.label) · \(resolution.label)\(frameRate.rawValue)"
    }

    /// "9:16 · 1080p30 · ideal 1:00–1:30"
    var summary: String {
        let ideal = DurationText.clock(idealRange.lowerBound) + "–" + DurationText.clock(idealRange.upperBound)
        return captureSummary + " · " + String(localized: "ideal \(ideal)")
    }
}
