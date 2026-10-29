//
//  VoiceEffect.swift
//  Cue Studio
//

import Foundation

/// A creative effect on a voice (Voice effects, on a clip or a voice-over): it changes how the voice sounds on purpose, for a
/// joke, a flashback or a phone call. Apart from Studio Voice, which only makes the voice clearer and never changes its
/// character. Made on the iPhone (`VoiceEffectRenderer`); the recording never changes, and None plays it as it was.
nonisolated enum VoiceEffect: String, Codable, CaseIterable, Identifiable, Sendable {
    case radio, megaphone, robot, deep, chipmunk, echo, hall

    var id: String { rawValue }

    var label: String {
        switch self {
        case .radio: String(localized: "Radio")
        case .megaphone: String(localized: "Megaphone")
        case .robot: String(localized: "Robot")
        case .deep: String(localized: "Deep voice")
        case .chipmunk: String(localized: "Chipmunk")
        case .echo: String(localized: "Echo")
        case .hall: String(localized: "Big hall")
        }
    }

    /// What it's for, in a few words.
    var use: String {
        switch self {
        case .radio: String(localized: "A call, an old recording")
        case .megaphone: String(localized: "Shouting, announcing")
        case .robot: String(localized: "A machine talking")
        case .deep: String(localized: "Lower, bigger voice")
        case .chipmunk: String(localized: "Higher, tiny voice")
        case .echo: String(localized: "A voice that repeats")
        case .hall: String(localized: "A big room, a stage")
        }
    }

    var systemImage: String {
        switch self {
        case .radio: "radio"
        case .megaphone: "megaphone"
        case .robot: "cpu"
        case .deep: "arrow.down.circle"
        case .chipmunk: "arrow.up.circle"
        case .echo: "dot.radiowaves.right"
        case .hall: "building.columns"
        }
    }

    /// Bumped when an effect's recipe changes, so files made with the old one aren't reused.
    static let version = 1
}
