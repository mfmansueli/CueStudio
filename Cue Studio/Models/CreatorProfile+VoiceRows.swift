//
//  CreatorProfile+VoiceRows.swift
//  Cue Studio
//

import Foundation

nonisolated extension VoiceField {
    /// The row's name on the full page (9.3).
    var title: String {
        switch self {
        case .role: String(localized: "I am")
        case .topics: String(localized: "Topics")
        case .audience: String(localized: "Audience")
        case .tone: String(localized: "Voice")
        case .style: String(localized: "Style")
        case .formats: String(localized: "Usual formats")
        case .openings: String(localized: "Opens with")
        case .endings: String(localized: "Ends with")
        case .phrases: String(localized: "My phrases")
        case .avoid: String(localized: "Avoid")
        case .reach: String(localized: "Reach")
        case .examples: String(localized: "Examples")
        }
    }

    /// The questions that fill this field, in the order they are asked.
    var questions: [VoiceQuestion] {
        VoiceQuestion.allCases.filter { $0.field == self }
    }

    /// The fields of a layer, in the order the page lists them.
    static func fields(of layer: VoiceLayer) -> [VoiceField] {
        allCases.filter { $0.layer == layer }
    }
}

nonisolated extension CreatorProfile {
    /// What the creator gave Cue for `field`, as readable values ("Calm · Short · Plain"); empty when nothing yet.
    func value(for field: VoiceField) -> String {
        let separator = " · "
        switch field {
        case .role: return customRole ?? role?.label ?? ""
        case .topics: return topics.map(\.label).joined(separator: separator)
        case .audience:
            guard isChosen(.audience) else { return "" }
            let who = audienceNote ?? audienceGroup?.label ?? vocabulary.audienceLabel
            return ([who] + [audienceLevel?.label].compactMap { $0 }).joined(separator: separator)
        case .tone: return isChosen(.tone) ? sounds.map(\.label).joined(separator: separator) : ""
        case .style:
            return [style.energy?.label, style.sentences?.label, style.words?.label, style.swearing?.label]
                .compactMap { $0 }.joined(separator: separator)
        case .formats:
            return (formatTags.map(VoiceQuestion.formatTagLabel) + formats.map(\.label)).joined(separator: separator)
        case .openings: return openings.joined(separator: separator)
        case .endings: return endings.joined(separator: separator)
        case .phrases: return phrases.joined(separator: separator)
        case .avoid: return avoidNone ? String(localized: "Nothing to avoid") : avoid.joined(separator: separator)
        case .reach:
            return (reach.platforms.map(\.label) + [reach.length?.label, reach.humor?.label].compactMap { $0 }).joined(separator: separator)
        case .examples: return examplesValue
        }
    }

    /// "2 of 3 · Imported: 12": what they wrote or imported as proof of how they talk.
    private var examplesValue: String {
        examplesSummary(own: examples.count, of: VoiceExample.limit)
    }

    /// The same for the page's row, which also counts the scripts they approved (`approvedSamples`) among what they gave.
    var examplesPageValue: String {
        examplesSummary(own: examples.count + approvedSamples.count, of: VoiceExample.limit + VoiceLimits.approvedSamples)
    }

    private func examplesSummary(own: Int, of limit: Int) -> String {
        switch (own, excerpts.count) {
        case (0, 0): ""
        case (let own, 0): String(localized: "\(own) of \(limit)")
        case (0, let imported): String(localized: "Imported: \(imported)")
        case (let own, let imported): String(localized: "\(own) of \(limit) · Imported: \(imported)")
        }
    }
}
