//
//  InspirationFilterOption.swift
//  Cue Studio
//

import Foundation

/// One chip of Find inspiration's filter row: "All my topics" first, then each topic the creator holds (the first flight's, the ones only
/// My Cue Voice offers and the ones they typed), in the order they hold them, each with its world's colour (`OnboardingTopic.color(at:)`).
nonisolated struct InspirationFilterOption: Hashable, Identifiable, Sendable {
    let filter: IdeaTopicFilter
    /// What the chip says; nil for "All my topics", which the view says in the interface's language.
    let label: String?
    /// The topic's place among the creator's topics: its world's colour. Nil for "All my topics".
    let worldIndex: Int?

    /// Stable and readable: `all`, `fitness`, `custom.daily-routine` (the chip's accessibility identifier ends with it).
    var id: String {
        switch filter {
        case .all: "all"
        case .topic(let topic): topic.niche?.rawValue ?? "custom." + Self.slug(topic.name)
        }
    }

    /// The chips for `topics`: "All my topics" and one per topic. A topic held twice (the same name) is one chip.
    static func options(for topics: [IdeaTopic]) -> [InspirationFilterOption] {
        var seen: Set<String> = []
        var options = [InspirationFilterOption(filter: .all, label: nil, worldIndex: nil)]
        for topic in topics {
            let key = slug(topic.name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            options.append(InspirationFilterOption(filter: .topic(topic), label: topic.label, worldIndex: options.count - 1))
        }
        return options
    }

    /// Where `idea` sits among `topics` (its world's colour), when it is about one of them.
    static func worldIndex(of idea: ThemeIdea, among topics: [IdeaTopic]) -> Int? {
        topics.firstIndex { IdeaTopicFilter.topic($0).includes(idea) }
    }

    /// The topic `idea` is about, as the creator reads it: theirs when it is one of theirs, else what the idea says.
    static func topicLabel(of idea: ThemeIdea, among topics: [IdeaTopic]) -> String {
        if let index = worldIndex(of: idea, among: topics) { return topics[index].label }
        return idea.topic ?? idea.niche.chipLabel
    }

    private static func slug(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
