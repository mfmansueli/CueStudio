//
//  WritingFinding+Display.swift
//  Cue Studio
//

import Foundation

nonisolated extension WritingFinding.Kind {
    /// The name of the row in the review.
    var title: String {
        switch self {
        case .tones: String(localized: "Voice")
        case .topics: String(localized: "Topics")
        case .audience: String(localized: "Audience")
        case .sentences: String(localized: "Sentences")
        case .words: String(localized: "Words")
        case .energy: String(localized: "Energy")
        case .humor: String(localized: "Humor")
        case .swearing: String(localized: "Swearing")
        case .speaksAs: String(localized: "Scripts say")
        case .length: String(localized: "Usual length")
        case .phrases: String(localized: "My phrases")
        case .openings: String(localized: "Opens with")
        case .endings: String(localized: "Ends with")
        }
    }
}

nonisolated extension WritingFinding.Value {
    /// What was found, in the creator's words.
    var display: String {
        let separator = " · "
        switch self {
        case .tones(let tones): return tones.map(\.label).joined(separator: separator)
        case .topics(let ids): return ids.compactMap { CreatorProfileService.topicRef(for: $0)?.label }.joined(separator: separator)
        case .audience(let group): return group.label
        case .sentences(let value): return value.label
        case .words(let value): return value.label
        case .energy(let value): return value.label
        case .humor(let value): return value.label
        case .swearing(let value): return value.label
        case .speaksAs(let value): return value.label
        case .length(let value): return value.label
        case .phrases(let phrases): return phrases.map { "“\($0)”" }.joined(separator: separator)
        case .openings(let ids): return ids.map(VoiceChoiceCatalog.openingLabel).joined(separator: separator)
        case .endings(let ids): return ids.map(VoiceChoiceCatalog.endingLabel).joined(separator: separator)
        }
    }
}

nonisolated extension WritingFinding.Kind {
    /// What the creator has for this now, so a finding that would replace it can say what it replaces; nil when they have nothing.
    func current(in profile: CreatorProfile) -> String? {
        let text: String? = switch self {
        case .tones: profile.hasAnswered(.tone) ? profile.value(for: .tone) : nil
        case .audience: profile.isChosen(.audience) ? profile.value(for: .audience) : nil
        case .sentences: profile.style.sentences?.label
        case .words: profile.style.words?.label
        case .energy: profile.style.energy?.label
        case .humor: profile.reach.humor?.label
        case .swearing: profile.style.swearing?.label
        case .speaksAs: profile.speaksAs?.label
        case .length: profile.reach.length?.label
        case .topics, .phrases, .openings, .endings: nil
        }
        return text?.isEmpty == false ? text : nil
    }
}
