//
//  VoiceVocabulary.swift
//  Cue Studio
//

import Foundation

/// The one-tap options of each Personality question (the nudges and the row sheets), always followed by "None of these" and
/// "+ Something else". Typed text is checked against them for typos.
nonisolated extension VoicePersonalityItem {
    /// The choices Cue offers, as the words that are saved.
    var options: [String] {
        switch self {
        case .openings:
            [
                String(localized: "Bold claim"), String(localized: "Question"), String(localized: "Story opener"),
                String(localized: "Surprising fact"), String(localized: "POV"),
            ]
        case .endings:
            [
                String(localized: "Save this"), String(localized: "Follow for more"), String(localized: "Comment your answer"),
                String(localized: "Link in bio"), String(localized: "Try it and tell me"),
            ]
        case .formats, .swearing, .phrases:
            []
        }
    }

    /// How many answers fit (`VoiceLimits`).
    var limit: Int {
        switch self {
        case .openings: VoiceLimits.openings
        case .endings: VoiceLimits.endings
        case .phrases: VoiceLimits.phrases
        case .formats: VoiceLimits.formats
        case .swearing: 1
        }
    }

    /// "Max 2 openings".
    var limitMessage: String {
        switch self {
        case .openings: VoiceLimits.message(max: limit, noun: String(localized: "openings"))
        case .endings: VoiceLimits.message(max: limit, noun: String(localized: "endings"))
        case .phrases: VoiceLimits.message(max: limit, noun: String(localized: "phrases"))
        case .formats: VoiceLimits.message(max: limit, noun: String(localized: "formats"))
        case .swearing: ""
        }
    }

    /// The row's name on the full page.
    var title: String {
        switch self {
        case .openings: String(localized: "Opens with")
        case .endings: String(localized: "Ends with")
        case .phrases: String(localized: "My phrases")
        case .formats: String(localized: "Usual formats")
        case .swearing: String(localized: "Swearing")
        }
    }
}

nonisolated extension CreatorProfile {
    /// What the creator gave Cue for a Personality item, as readable values.
    func values(for item: VoicePersonalityItem) -> [String] {
        switch item {
        case .openings: openings
        case .endings: endings
        case .phrases: phrases
        case .formats: formats.map(\.label)
        case .swearing: swearing.map { [$0.label] } ?? []
        }
    }
}
