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
    /// Which reading of the preset draws (`CaptionStyleSpec`): nil in settings saved before the
    /// complete presets, which keep the look they were made with.
    var styleVersion: Int?
    /// A text's look copied onto the captions (Text style › "Apply this style to captions"): the
    /// lines are drawn in its font, colors, fill, shadow and glow instead of the preset's. The rest
    /// stays the collection's: where the lines sit, their size, the highlight color and how they
    /// come and go (the preset's own way, `spec`). Nil draws the preset; picking a preset clears it.
    /// Settings saved before it read as nil.
    var customLook: TextLook?

    init(theme: CaptionTheme = .cue) {
        self.theme = theme
        styleVersion = CaptionStyleSpec.currentVersion
        followsWords = CaptionStyleSpec.spec(for: theme, version: CaptionStyleSpec.currentVersion).animation.followsWords
    }

    /// The recipe the preset is drawn with.
    var spec: CaptionStyleSpec { CaptionStyleSpec.spec(for: theme, version: styleVersion ?? 1) }

    var highlightColor: CaptionAccent { accent ?? spec.defaultAccent }
    var clampedScale: Double {
        min(max(sizeScale.isFinite ? sizeScale : 1, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
    }
}
