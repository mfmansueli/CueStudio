//
//  TextEffect.swift
//  Cue Studio
//

import Foundation

/// A finished look on a text (`TextEffectKind`) and how the creator tuned it: its second color or metal, how strong it is,
/// whether it moves, how long its way in takes and which way it goes. It decorates the words the creator wrote; it never
/// changes them, nor where, when or how big the text is. Its motion happens inside the text's box, so the text's place,
/// keyframes and Track stay the creator's (`OverlayMotion`); a ready-made Motion (`OverlayAnimation`) plays instead of it, never
/// with it (`TextOverlay.playsEffectMotion`).
nonisolated struct TextEffect: Codable, Hashable, Sendable {
    static let intensityRange: ClosedRange<Double> = 0...1

    var kind: TextEffectKind
    /// The depth's color (Pop 3D) or the band's (Headline).
    var accent: OverlayColor
    /// The Gold effect's metal.
    var tone: MetalTone = .gold
    /// 0 to 1: the kind's own strength (`TextEffectKind.intensityLabel`).
    var intensity: Double
    var motion: TextEffectMotion = .animated
    /// Seconds its way in takes; the way out takes a little less (`TextEffectChoreography.timing`).
    var duration: TimeInterval
    var direction: TextEffectDirection

    /// `kind` as it comes: its own defaults.
    init(_ kind: TextEffectKind) {
        self.kind = kind
        accent = kind.defaultAccent
        intensity = kind.defaultIntensity
        duration = kind.defaultDuration
        direction = kind.directions.first ?? .start
    }

    /// Whether it plays its own way in and out.
    var isAnimated: Bool { motion == .animated }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case kind, accent, tone, intensity, motion, duration, direction
    }

    /// A field this version doesn't know, or a value out of range, falls back to the kind's own.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let report = decoder.decodingReport
        let kind = container.decodeChoice(TextEffectKind.self, forKey: .kind, unknown: .fallback, report: report) ?? .fallback
        self.init(kind)
        accent = container.decodeChoice(OverlayColor.self, forKey: .accent, unknown: kind.defaultAccent, report: report) ?? kind.defaultAccent
        tone = container.decodeChoice(MetalTone.self, forKey: .tone, unknown: .fallback, report: report) ?? .gold
        if let value = try? container.decodeIfPresent(Double.self, forKey: .intensity), value.isFinite {
            intensity = min(max(value, Self.intensityRange.lowerBound), Self.intensityRange.upperBound)
        }
        motion = container.decodeChoice(TextEffectMotion.self, forKey: .motion, unknown: .fallback, report: report) ?? .animated
        if let value = try? container.decodeIfPresent(Double.self, forKey: .duration), value.isFinite {
            duration = min(max(value, TextEffectKind.durationRange.lowerBound), TextEffectKind.durationRange.upperBound)
        }
        if let value = container.decodeChoice(TextEffectDirection.self, forKey: .direction, unknown: .fallback, report: report),
           kind.directions.contains(value) {
            direction = value
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(accent, forKey: .accent)
        try container.encode(tone, forKey: .tone)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(motion, forKey: .motion)
        try container.encode(duration, forKey: .duration)
        try container.encode(direction, forKey: .direction)
    }
}
