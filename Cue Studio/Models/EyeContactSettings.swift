//
//  EyeContactSettings.swift
//  Cue Studio
//

import Foundation

/// Eye Contact (✦ Smart): the creator's eyes moved toward the lens where they read the script below it, on every recording the edit
/// plays (never on photos or videos laid over the take). Only the intent is kept with the edit: how strong, and which engine drew it.
/// What was found in each recording is a cache next to it (`EyeContactAnalysisStore`), made again whenever it's missing.
nonisolated struct EyeContactSettings: Codable, Hashable, Sendable {
    /// The engine every new edit gets (`EyeContactEngine`).
    static let currentEngine = 2
    /// What the creator gets when they turn it on: the whole angle between the teleprompter's text and the lens, as measured from
    /// the face's distance (`EyeGazePlan.degrees`); less moves the eyes part of the way.
    static let defaultStrength = 1.0
    static let strengthRange: ClosedRange<Double> = 0.2...1

    /// How far the eyes are moved, `strengthRange` (1 is the measured angle).
    var strength: Double {
        didSet { strength = Self.clamped(strength) }
    }
    /// The engine (model and rules) this edit was drawn with. An edit from an engine this version no longer has is moved to the
    /// current one when it's read (`TakeEdit`), so it never draws differently without saying so in the export's fingerprint.
    var engine: Int

    init(strength: Double = Self.defaultStrength, engine: Int = Self.currentEngine) {
        self.strength = Self.clamped(strength)
        self.engine = engine
    }

    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return defaultStrength }
        return min(max(value, strengthRange.lowerBound), strengthRange.upperBound)
    }

    private enum CodingKeys: String, CodingKey { case strength, engine }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strength = Self.clamped((try? container.decodeIfPresent(Double.self, forKey: .strength)) ?? Self.defaultStrength)
        // Only one engine so far: anything else is read as it.
        engine = Self.currentEngine
    }
}
