//
//  IdeaTaste.swift
//  Cue Studio
//

import Foundation

/// What the creator's taps say about the ideas they want. A creator taps "↻" (or "Another idea" in Find inspiration) until an idea is one they would
/// film; the ones they pass, the one they pick and the one that becomes a script are the only honest signal of what they like, so all are remembered, by
/// angle and by topic, and the next ideas are asked for more of what they use and less of what they pass. Four signals, from weakest to strongest:
/// passing an idea (it may only have been the wrong one that day), picking it to change in the field ("Start with it": liked, not yet used), sending
/// the card's idea as it is, and a script written from a brief (`generated`). Never all of it: some of every batch is left to look at other angles,
/// because a taste that only narrows ends in the same idea over and over.
nonisolated struct IdeaTaste: Codable, Hashable, Sendable {
    /// What a send is worth, and what a pass costs (an idea passed may only have been the wrong one that day).
    static let sendWeight = 3.0
    static let passWeight = 0.35
    /// Picked to change: half a send, since the creator may still take the idea somewhere else.
    static let selectWeight = 1.5
    /// A script was written from it: what they want, more than anything they tapped.
    static let generateWeight = 4.0
    /// How many of a batch's six look at the angles the creator likes; the rest are the ones they have seen least.
    static let favoured = 4

    private(set) var angles: [String: Double] = [:]
    private(set) var topics: [String: Double] = [:]
    private(set) var seenAngles: [String: Int] = [:]

    mutating func passed(_ idea: ThemeIdea) { record(idea, weight: -Self.passWeight) }
    mutating func sent(_ idea: ThemeIdea) { record(idea, weight: Self.sendWeight) }
    mutating func selected(_ idea: ThemeIdea) { record(idea, weight: Self.selectWeight) }

    /// A script was written from `brief`, what of it the creator's text still said: its topic counts, and its angle only when the angle still stood
    /// (a creator who rewrote the angle made the video about the topic, not about that way of looking at it).
    mutating func generated(_ brief: IdeaBrief) {
        if let angle = brief.angleKind, !brief.angle.isEmpty { angles[angle, default: 0] += Self.generateWeight }
        if let topic = brief.topicKey { topics[topic, default: 0] += Self.generateWeight }
    }

    private mutating func record(_ idea: ThemeIdea, weight: Double) {
        if let angle = idea.angle ?? idea.brief?.angleKind { angles[angle, default: 0] += weight }
        topics[Self.topicKey(of: idea), default: 0] += weight
    }

    mutating func showed(_ idea: ThemeIdea) {
        if let angle = idea.angle ?? idea.brief?.angleKind { seenAngles[angle, default: 0] += 1 }
    }

    /// How a topic is kept: a first-flight niche by its raw value, any other topic by its label (what `IdeaTopicFilter` and the slots match on).
    static func topicKey(of idea: ThemeIdea) -> String {
        idea.topic ?? idea.niche.rawValue
    }

    static func topicKey(of topic: IdeaTopic) -> String {
        topic.niche?.rawValue ?? topic.label
    }

    /// The six ideas to ask for in a round: the creator's favourite angles first, then the ones seen least, and the topics in turn, the ones they send
    /// more often.
    func slots(round: Int, among topics: [IdeaTopic], count: Int = IdeaAngle.batchSize) -> [IdeaSlot] {
        guard !topics.isEmpty else { return [] }
        let chosen = Self.favourites(angles, round: round, count: min(Self.favoured, count))
        let rest = IdeaAngle.allCases.filter { !chosen.contains($0) }
        let explored = rest.sorted { lhs, rhs in
            let (left, right) = (seenAngles[lhs.rawValue, default: 0], seenAngles[rhs.rawValue, default: 0])
            return left == right ? Self.position(of: lhs, round: round) < Self.position(of: rhs, round: round) : left < right
        }.prefix(count - chosen.count)
        let angles = Array(chosen + explored)
        let order = turns(among: topics, round: round, count: angles.count)
        return zip(angles, order).map { angle, topic in IdeaSlot(angle: angle, topic: topic) }
    }

    /// The angles the creator has sent most, best first; with nothing sent yet (or too few to say) the angles rotate as they always did.
    private static func favourites(_ scores: [String: Double], round: Int, count: Int) -> [IdeaAngle] {
        let liked = IdeaAngle.allCases.filter { scores[$0.rawValue, default: 0] > 0 }
            .sorted { scores[$0.rawValue, default: 0] > scores[$1.rawValue, default: 0] }
        // However much they like an angle, it does not take every slot: the first rounds' rotation fills what the liked ones don't.
        let taken = Array(liked.prefix(max(1, count / 2)))
        let rotation = IdeaAngle.batch(round: round, count: count).filter { !taken.contains($0) }
        return Array((taken + rotation).prefix(count))
    }

    /// Ideas already written (the starters) in the order the creator's taste reads them: one of an angle they use, then one of the others, in
    /// turn, so what they like comes first without hiding the rest; the angles they pass go last. Ideas of equal standing keep their order.
    func ordered(_ ideas: [ThemeIdea]) -> [ThemeIdea] {
        func score(_ idea: ThemeIdea) -> Double { (idea.angle ?? idea.brief?.angleKind).map { angles[$0, default: 0] } ?? 0 }
        func ranked(_ part: [(offset: Int, element: ThemeIdea)]) -> [ThemeIdea] {
            part.sorted { score($0.element) == score($1.element) ? $0.offset < $1.offset : score($0.element) > score($1.element) }.map(\.element)
        }
        let numbered = Array(ideas.enumerated()).map { (offset: $0.offset, element: $0.element) }
        let liked = ranked(numbered.filter { score($0.element) > 0 })
        let rest = ranked(numbered.filter { score($0.element) <= 0 })
        var order: [ThemeIdea] = []
        for index in 0..<max(liked.count, rest.count) {
            if index < liked.count { order.append(liked[index]) }
            if index < rest.count { order.append(rest[index]) }
        }
        return order
    }

    /// The most turns a topic takes in a round's order.
    static let mostTurns = 3

    /// The turns a topic has before the creator sends anything: two when it is in their own words, one when it is a broad first-flight topic.
    static func firstTurns(of topic: IdeaTopic) -> Int {
        topic.niche == nil || !topic.subtopics.isEmpty ? 2 : 1
    }

    private static func position(of angle: IdeaAngle, round: Int) -> Int {
        let all = IdeaAngle.allCases
        guard let index = all.firstIndex(of: angle) else { return 0 }
        return (index - (round * IdeaAngle.batchSize) % all.count + all.count) % all.count
    }

    /// The topics the slots take, in order: each in proportion to its turns, as many as the creator sends it (one more than it has been sent, at
    /// most three), spread so that no topic runs on while another waits (a smooth weighted round-robin), starting one further each round. A topic
    /// the creator put in their own words (typed, or a first-flight one narrowed by subtopics) starts with one turn more than a broad one: "Filming
    /// videos with a phone" says what they make, "Education" and "Tech" next to it only roughly (with equal turns, half the ideas were about
    /// teaching and AI, 31/10/2026).
    private func turns(among topics: [IdeaTopic], round: Int, count: Int) -> [IdeaTopic] {
        guard !topics.isEmpty else { return [] }
        let shift = round % topics.count
        let rotated = Array(topics[shift...] + topics[..<shift])
        let weights = rotated.map { topic in
            let sent = max(0, Int((self.topics[Self.topicKey(of: topic), default: 0] / Self.sendWeight).rounded(.down)))
            return min(Self.mostTurns, Self.firstTurns(of: topic) + sent)
        }
        let total = weights.reduce(0, +)
        var current = Array(repeating: 0, count: rotated.count)
        var order: [IdeaTopic] = []
        for _ in 0..<count {
            for index in current.indices { current[index] += weights[index] }
            guard let pick = current.indices.max(by: { current[$0] < current[$1] || (current[$0] == current[$1] && $0 > $1) }) else { break }
            current[pick] -= total
            order.append(rotated[pick])
        }
        return order
    }
}
