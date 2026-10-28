//
//  ClipAnimation.swift
//  Cue Studio
//

import Foundation

/// A clip's way in at its start or out at its end (Animation): a style and how long it takes. Pure: the preview, the export and
/// the tests read the same motion (`modifier`).
nonisolated struct ClipAnimation: Codable, Hashable, Sendable {
    static let durationRange: ClosedRange<TimeInterval> = 0.2...1.5
    static let defaultDuration: TimeInterval = 0.5

    var style: ClipAnimationStyle
    var duration: TimeInterval

    init(style: ClipAnimationStyle, duration: TimeInterval = ClipAnimation.defaultDuration) {
        self.style = style
        self.duration = min(max(duration.isFinite ? duration : Self.defaultDuration, Self.durationRange.lowerBound), Self.durationRange.upperBound)
    }

    /// What the clip's picture is `elapsed` seconds into the way in (`isIn`), or `elapsed` seconds before its end on the way out,
    /// lasting `length` seconds. Shown as it is past the end of the motion.
    static func frame(_ style: ClipAnimationStyle, isIn: Bool, elapsed: TimeInterval, length: TimeInterval) -> ClipAnimationFrame {
        guard length > 0 else { return .still }
        let into = min(max(elapsed / length, 0), 1)
        // Smoothstep: it eases off as it settles (in), and eases in as it leaves (out, read backwards from the end).
        let shown = into * into * (3 - 2 * into)
        let hidden = 1 - shown
        switch style {
        case .fade: return ClipAnimationFrame(opacity: shown)
        case .rise: return ClipAnimationFrame(dy: 0.12 * hidden, opacity: shown)
        // In from the leading side, out the trailing one.
        case .slide: return ClipAnimationFrame(dx: (isIn ? -1 : 1) * hidden)
        case .zoom: return ClipAnimationFrame(scale: 0.75 + 0.25 * shown, opacity: shown)
        case .blur: return ClipAnimationFrame(blur: 0.04 * hidden)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case style, duration
    }

    /// Lenient: a style from a newer version reads as a fade (`LenientChoice`), a strange duration as the nearest one allowed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let duration = (try? container.decodeIfPresent(TimeInterval.self, forKey: .duration)) ?? Self.defaultDuration
        self.init(style: try container.decode(ClipAnimationStyle.self, forKey: .style), duration: duration)
    }
}
