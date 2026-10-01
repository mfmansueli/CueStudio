//
//  CaptionSettings.swift
//  Cue Studio
//

import Foundation

/// Local visual changes never request another transcription. Nil in TakeEdit means legacy.
nonisolated struct CaptionSettings: Codable, Hashable, Sendable {
    static let sizeRange: ClosedRange<Double> = 0.65...1.65

    var theme: CaptionTheme = .cue
    var sizeScale: Double = 1
    var center: OverlayPoint?
    var accent: CaptionAccent?
    var followsWords = true
    /// Captured from the project's platform, independent of later rules updates.
    var safeMargins = SafeZoneMargins()

    init(theme: CaptionTheme = .cue) {
        self.theme = theme
        followsWords = theme != .clean
    }

    var highlightColor: CaptionAccent { accent ?? theme.defaultAccent }
    var clampedScale: Double {
        min(max(sizeScale.isFinite ? sizeScale : 1, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
    }
}
