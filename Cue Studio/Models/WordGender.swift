//
//  WordGender.swift
//  Cue Studio
//

import Foundation

/// How the words about the creator agree, in the languages that mark it ("cansada", "je suis allée", "sono arrivata", "me quedé sola"): the
/// owner's B8 (02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11.7). Not chosen (nil) is never the masculine: Cue then
/// avoids the words that would mark it. `neutral` is the creator's own choice of no gender: rephrased, never invented forms ("todes", "elu").
nonisolated enum WordGender: String, Codable, CaseIterable, Identifiable, Sendable {
    case feminine, masculine, neutral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feminine: String(localized: "Feminine")
        case .masculine: String(localized: "Masculine")
        case .neutral: String(localized: "No gender")
        }
    }

    /// What iOS knows of the person (Settings › General › Language & Region › Term of Address), as a suggestion only: the script may be someone
    /// else's, or a team's. Nil when it is not set.
    static var fromThisDevice: WordGender? {
        // `Morphology.user` is only reachable through its Objective-C class (measured with `CreatorInputsDeviceTests.recordsTheTermOfAddress`).
        let user = __NSMorphology.user
        guard !user.isUnspecified else { return nil }
        return switch (user as Morphology).grammaticalGender {
        case .feminine: .feminine
        case .masculine: .masculine
        case .neuter: .neutral
        default: nil
        }
    }
}
