//
//  SoundEffectCategory.swift
//  Cue Studio
//

import Foundation

/// The groups the sound effects are filed in, by what they're used for, in the order they show
/// (`SoundEffect.effects(in:)` lists each one's effects).
nonisolated enum SoundEffectCategory: String, CaseIterable, Identifiable, Sendable {
    case transitions, textAndGraphics, reactions, comedy, bigMoments, alertsAndTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transitions: String(localized: "Transitions")
        case .textAndGraphics: String(localized: "Text & graphics")
        case .reactions: String(localized: "Reactions")
        case .comedy: String(localized: "Comedy")
        case .bigMoments: String(localized: "Big moments")
        case .alertsAndTime: String(localized: "Alerts & time")
        }
    }

    var systemImage: String {
        switch self {
        case .transitions: "arrow.left.arrow.right"
        case .textAndGraphics: "textformat"
        case .reactions: "face.smiling"
        case .comedy: "theatermasks"
        case .bigMoments: "flame"
        case .alertsAndTime: "alarm"
        }
    }

    /// Its effects, in display order.
    var effects: [SoundEffect] { SoundEffect.effects(in: self) }
}
