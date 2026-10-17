//
//  SoundEffect.swift
//  Cue Studio
//

import Foundation

/// The sound effects Cue offers: a small set for creator videos, every one made by Cue on the device (`SoundEffectSynth`), so
/// there is no file of unknown origin or license in the app or in the videos made with it.
nonisolated enum SoundEffect: String, Codable, CaseIterable, Identifiable, Sendable {
    case whoosh, pop, click, ding, sparkle, riser, boom, ping, typing, shutter, buzzer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .whoosh: String(localized: "Whoosh")
        case .pop: String(localized: "Pop", comment: "Sound effect")
        case .click: String(localized: "Click")
        case .ding: String(localized: "Ding")
        case .sparkle: String(localized: "Sparkle")
        case .riser: String(localized: "Riser")
        case .boom: String(localized: "Boom")
        case .ping: String(localized: "Ping")
        case .typing: String(localized: "Typing")
        case .shutter: String(localized: "Shutter")
        case .buzzer: String(localized: "Wrong")
        }
    }

    /// What it's for, in a word or two.
    var use: String {
        switch self {
        case .whoosh: String(localized: "Transitions")
        case .pop: String(localized: "Text appears")
        case .click: String(localized: "Taps, steps")
        case .ding: String(localized: "Right answer")
        case .sparkle: String(localized: "Reveal")
        case .riser: String(localized: "Build-up")
        case .boom: String(localized: "Big moment")
        case .ping: String(localized: "Notification")
        case .typing: String(localized: "Words typed")
        case .shutter: String(localized: "Photo")
        case .buzzer: String(localized: "Mistake")
        }
    }

    var systemImage: String {
        switch self {
        case .whoosh: "wind"
        case .pop: "circle.dotted"
        case .click: "cursorarrow.click"
        case .ding: "bell"
        case .sparkle: "sparkles"
        case .riser: "arrow.up.right"
        case .boom: "burst"
        case .ping: "bell.badge"
        case .typing: "keyboard"
        case .shutter: "camera.shutter.button"
        case .buzzer: "xmark.octagon"
        }
    }

    /// Bumped when a sound's recipe changes, so files made with the old one aren't reused.
    static let version = 1
}
