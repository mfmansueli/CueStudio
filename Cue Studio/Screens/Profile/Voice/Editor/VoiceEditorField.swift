//
//  VoiceEditorField.swift
//  Cue Studio
//

import Foundation

/// What the one voice editor can show (My Cue Voice · screen 2): every row of the page opens it on the field that holds its answer. The first four are the
/// four guided questions; the rest are the Personality and Proof layers.
enum VoiceEditorField: String, CaseIterable, Identifiable {
    case role, topics, audience, tone, formats, phrases, reach, examples

    var id: String { rawValue }

    /// The editor behind a row of the page. Why they watch is part of "Who's watching?", and the style is part of how they talk.
    init(_ row: VoicePageRow) {
        switch row {
        case .role: self = .role
        case .topics: self = .topics
        case .audience, .watch: self = .audience
        case .tone, .style: self = .tone
        case .formats, .openings, .endings, .goals: self = .formats
        case .phrases, .avoid: self = .phrases
        case .reach: self = .reach
        case .examples: self = .examples
        }
    }

    /// The editor of the field a question of the bank fills.
    init(_ field: VoiceField) {
        switch field {
        case .role: self = .role
        case .topics: self = .topics
        case .audience: self = .audience
        case .tone, .style: self = .tone
        case .formats, .openings, .endings: self = .formats
        case .phrases, .avoid: self = .phrases
        case .reach: self = .reach
        case .examples: self = .examples
        }
    }

    /// The editor of a step of the guided questions.
    init(_ step: VoiceSetupStep) {
        switch step {
        case .role: self = .role
        case .niche: self = .topics
        case .audience: self = .audience
        case .tone: self = .tone
        }
    }

    var title: String {
        switch self {
        case .role: String(localized: "What kind of creator are you?")
        case .topics: String(localized: "What do you talk about?")
        case .audience: String(localized: "Who’s watching?")
        case .tone: String(localized: "How do you talk on camera?")
        case .formats: String(localized: "Formats, openings, endings")
        case .phrases: String(localized: "Phrases & limits")
        case .reach: String(localized: "Platforms & length")
        case .examples: String(localized: "How you really talk")
        }
    }

    /// The line above the title, in mono capitals ("Essentials · 2 of 4 · 1 of 3").
    func eyebrow(for profile: CreatorProfile) -> String {
        switch self {
        case .role: String(localized: "Essentials · 1 of 4")
        case .topics: String(localized: "Essentials · 2 of 4 · \(profile.topicCount) of \(VoiceLimits.topics)")
        case .audience: String(localized: "Essentials · 3 of 4")
        case .tone: String(localized: "Essentials · 4 of 4")
        case .formats: String(localized: "Personality · how your videos work")
        case .phrases: String(localized: "Personality · your words")
        case .reach: String(localized: "Personality · where it goes")
        case .examples: String(localized: "Proof · \(profile.examples.count) of \(VoiceExample.limit) examples")
        }
    }
}
