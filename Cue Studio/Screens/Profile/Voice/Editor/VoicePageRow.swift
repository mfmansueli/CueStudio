//
//  VoicePageRow.swift
//  Cue Studio
//

import Foundation

/// A row of the My Cue Voice page (screen 3), in the order the page shows them. Most are one `VoiceField`; "They watch to", the style and what the videos
/// are for are answers that sit inside another field, shown as rows of their own because they are what the creator looks for.
enum VoicePageRow: String, CaseIterable, Identifiable {
    case role, topics, audience, watch, tone
    case style, formats, openings, endings, goals, phrases, avoid, reach
    case examples

    var id: String { rawValue }

    var layer: VoiceLayer {
        switch self {
        case .role, .topics, .audience, .watch, .tone: .essentials
        case .examples: .proof
        default: .personality
        }
    }

    static func rows(of layer: VoiceLayer) -> [VoicePageRow] {
        allCases.filter { $0.layer == layer }
    }

    var title: String {
        switch self {
        case .role: String(localized: "I am")
        case .topics: String(localized: "Topics")
        case .audience: String(localized: "Audience")
        case .watch: String(localized: "They watch to")
        case .tone: String(localized: "Voice")
        case .style: String(localized: "Style")
        case .formats: String(localized: "Usual formats")
        case .openings: String(localized: "Opens with")
        case .endings: String(localized: "Ends with")
        case .goals: String(localized: "Videos are for")
        case .phrases: String(localized: "My phrases")
        case .avoid: String(localized: "Avoid")
        case .reach: String(localized: "Reach")
        case .examples: String(localized: "Examples")
        }
    }

    /// What Cue knows for the row, as readable values; empty when nothing yet.
    func value(in profile: CreatorProfile) -> String {
        let separator = " · "
        switch self {
        case .role:
            return ([profile.customRole ?? profile.role?.label, profile.credential].compactMap { $0 }).joined(separator: separator)
        case .topics:
            return profile.topics.map { topic in
                let subtopics = profile.subtopics(of: topic).map(VoiceSubtopicCatalog.displayName(of:))
                return subtopics.isEmpty ? topic.label : "\(topic.label) (\(subtopics.joined(separator: ", ")))"
            }.joined(separator: separator)
        case .audience:
            guard profile.isChosen(.audience) else { return "" }
            return ([profile.audienceNote ?? profile.audienceGroup?.label ?? profile.vocabulary.audienceLabel, profile.audienceLevel?.label]
                .compactMap { $0 }).joined(separator: separator)
        case .watch: return profile.watchReasons.map(\.label).joined(separator: separator)
        case .tone: return profile.isChosen(.tone) ? profile.sounds.map(\.label).joined(separator: separator) : ""
        case .style:
            let style = profile.style
            return [style.energy?.label, style.sentences?.label, style.words?.label, style.swearing?.label, profile.reach.humor?.label]
                .compactMap { $0 }.joined(separator: separator)
        case .formats: return profile.value(for: .formats)
        case .openings: return profile.openings.joined(separator: separator)
        case .endings: return profile.endings.joined(separator: separator)
        case .goals: return profile.contentGoals.map(\.label).joined(separator: separator)
        case .phrases: return profile.phrases.joined(separator: separator)
        case .avoid: return profile.value(for: .avoid)
        case .reach:
            return (profile.reach.platforms.map(\.label) + [profile.reach.length?.label].compactMap { $0 }).joined(separator: separator)
        case .examples: return profile.examplesPageValue
        }
    }
}
