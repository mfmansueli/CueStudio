//
//  CreatorProfile+VoiceRows.swift
//  Cue Studio
//

import Foundation

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
            return [
                style.energy?.label, style.sentences?.label, style.words?.label, style.swearing?.label,
                style.oneIdea ? VoiceDelivery.oneIdeaLabel : nil,
            ].compactMap { $0 }.joined(separator: separator)
        case .formats:
            return (formatTags.map(VoiceQuestion.formatTagLabel) + formats.map(\.label) + customFormats).joined(separator: separator)
        case .openings: return openings.joined(separator: separator)
        case .endings: return endings.joined(separator: separator)
        case .phrases: return phrases.joined(separator: separator)
        case .avoid: return avoidNone ? String(localized: "Nothing to avoid") : avoid.joined(separator: separator)
        case .reach:
            return (reach.platforms.map(\.label) + [reach.length?.label, reach.humor?.label].compactMap { $0 }).joined(separator: separator)
        case .examples: return examplesValue
        }
    }

    /// "2 of 3 · Imported: 12": what they wrote or imported as proof of how they talk (the scripts they approved show in "What Cue learned").
    private var examplesValue: String {
        examplesSummary(own: examples.count, of: VoiceExample.limit)
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
