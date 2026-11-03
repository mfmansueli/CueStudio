//
//  IdeaSlot.swift
//  Cue Studio
//

import Foundation

/// One idea to be written: the way it looks at its topic and which topic it is about.
nonisolated struct IdeaSlot: Hashable, Sendable {
    var angle: IdeaAngle
    var topic: IdeaTopic
    /// What it is tied to besides (an occasion, a video they posted, a comment), when it is (`IdeaSignals.tie`).
    var tie: IdeaTie?
    /// The concrete thing it is about, from the topic's ingredients (`IdeaIngredientStore`); nil: the topic in general.
    var subject: String?
    /// Another of the creator's topics it joins in one idea (`bridging`); nil: its own topic alone.
    var bridge: IdeaTopic?
    /// Left without a subject, so the model finds its own way into the topic (`opening`).
    var isOpen = false
    /// One of the topic's subtopics it stays inside (`focusing`); nil: the whole topic.
    var subtopic: String?
}

nonisolated extension IdeaSlot {
    /// How many ideas of a batch join two of the creator's topics: the owner (03/11/2026), "4 de 12".
    static let bridgesPerBatch = 2
    /// How many ideas of a batch are left without a subject: the owner (03/11/2026), some generality "helps the AI find ways to create".
    static let openPerBatch = 1
    /// The angles two topics meet in best, chosen first for a bridge: a comparison, a list, a tool, a day, a story, a how-to.
    private static let bridgeAngles: Set<IdeaAngle> = [.comparison, .list, .tool, .dayInLife, .story, .tutorial, .challenge, .beforeAfter]

    /// `slots` with `bridgesPerBatch` of them joining their topic with another of `topics` in one idea, the angles two topics meet in first. The
    /// pairs of topics take turns, two different ones in a batch where there are (measured with three topics on 03/11/2026, turning the partner
    /// of each slot gave AI with cooking 6 of 12 joins). A slot tied to something else (`tie`) is about that, and a creator with one topic has
    /// nothing to join. Joined ideas get no subject (`IdeaIngredientStore.seasoned`): the two topics are what they are about.
    static func bridging(_ slots: [IdeaSlot], among topics: [IdeaTopic], round: Int) -> [IdeaSlot] {
        guard topics.count >= 2 else { return slots }
        let pairs = topics.indices.flatMap { first in topics.indices.filter { $0 > first }.map { (first, $0) } }
        let free = slots.indices.filter { slots[$0].tie == nil }
        var order = free.filter { bridgeAngles.contains(slots[$0].angle) } + free.filter { !bridgeAngles.contains(slots[$0].angle) }
        var bridged = slots
        for turn in 0..<bridgesPerBatch {
            let (one, other) = pairs[(round * bridgesPerBatch + turn) % pairs.count]
            guard let place = order.firstIndex(where: { [one, other].contains(topics.firstIndex(of: slots[$0].topic)) }) else { continue }
            let index = order.remove(at: place)
            bridged[index].bridge = topics[topics.firstIndex(of: slots[index].topic) == one ? other : one]
        }
        return bridged
    }

    /// `slots` each inside one of its topic's subtopics, in turn as the batches go by, where it has no subject, tie or other topic of its own: the
    /// creator says what they cover inside a theme (up to `VoiceLimits.details`), and the ideas go through all of it instead of the theme in general.
    static func focusing(_ slots: [IdeaSlot], round: Int) -> [IdeaSlot] {
        let free = slots.indices.filter {
            slots[$0].subject == nil && slots[$0].tie == nil && slots[$0].bridge == nil && !slots[$0].topic.subtopics.isEmpty
        }
        var focused = slots
        for index in free {
            // In turn within each topic: the batch's first of a topic takes the subtopic after the last batch's last.
            let topic = slots[index].topic
            let mine = free.filter { slots[$0].topic == topic }
            let turn = round * mine.count + (mine.firstIndex(of: index) ?? 0)
            focused[index].subtopic = topic.subtopics[turn % topic.subtopics.count]
        }
        return focused
    }

    /// `slots` with `openPerBatch` of the ones neither tied nor joined left open (`isOpen`), a different angle each batch.
    static func opening(_ slots: [IdeaSlot], round: Int) -> [IdeaSlot] {
        let candidates = slots.indices.filter { slots[$0].tie == nil && slots[$0].bridge == nil }
        guard !candidates.isEmpty else { return slots }
        var opened = slots
        for turn in 0..<min(openPerBatch, candidates.count) {
            opened[candidates[(round + turn) % candidates.count]].isOpen = true
        }
        return opened
    }
}
