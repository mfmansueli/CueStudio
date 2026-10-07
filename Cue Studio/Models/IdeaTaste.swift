//
//  IdeaTaste.swift
//  Cue Studio
//

import Foundation

/// One idea to be written: the way it looks at its topic and which topic it is about.
nonisolated struct IdeaSlot: Hashable, Sendable {
    var angle: IdeaAngle
    var topic: IdeaTopic
}

/// What the creator's taps say about the ideas they want. A creator taps "↻" until an idea is one they would film; the ones they pass and the one they
/// send are the only honest signal of what they like, so both are remembered, by angle and by topic, and the next ideas are asked for more of what
/// they send and less of what they pass. Never all of it: some of every batch is left to look at other angles, because a taste that only narrows
/// ends in the same idea over and over.
nonisolated struct IdeaTaste: Codable, Hashable, Sendable {
    /// What a send is worth, and what a pass costs (an idea passed may only have been the wrong one that day).
    static let sendWeight = 3.0
    static let passWeight = 0.35
    /// How many of a batch's six look at the angles the creator likes; the rest are the ones they have seen least.
    static let favoured = 4

    private(set) var angles: [String: Double] = [:]
    private(set) var topics: [String: Double] = [:]
    private(set) var seenAngles: [String: Int] = [:]

    mutating func passed(_ idea: ThemeIdea) { record(idea, weight: -Self.passWeight) }
    mutating func sent(_ idea: ThemeIdea) { record(idea, weight: Self.sendWeight) }

    private mutating func record(_ idea: ThemeIdea, weight: Double) {
        if let angle = idea.angle { angles[angle, default: 0] += weight }
        let topic = idea.topic ?? idea.niche.rawValue
        topics[topic, default: 0] += weight
    }

    mutating func showed(_ idea: ThemeIdea) {
        if let angle = idea.angle { seenAngles[angle, default: 0] += 1 }
    }

    /// The six ideas to ask for in a round: the creator's favourite angles first, then the ones seen least, and the topics in turn, the ones they send
    /// more often.
    func slots(round: Int, among topics: [IdeaTopic], count: Int = 6) -> [IdeaSlot] {
        guard !topics.isEmpty else { return [] }
        let chosen = Self.favourites(angles, round: round, count: min(Self.favoured, count))
        let rest = IdeaAngle.allCases.filter { !chosen.contains($0) }
        let explored = rest.sorted { lhs, rhs in
            let (left, right) = (seenAngles[lhs.rawValue, default: 0], seenAngles[rhs.rawValue, default: 0])
            return left == right ? Self.position(of: lhs, round: round) < Self.position(of: rhs, round: round) : left < right
        }.prefix(count - chosen.count)
        let angles = Array(chosen + explored)
        let order = turns(among: topics, round: round)
        return angles.enumerated().map { index, angle in IdeaSlot(angle: angle, topic: order[index % order.count]) }
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

    private static func position(of angle: IdeaAngle, round: Int) -> Int {
        let all = IdeaAngle.allCases
        guard let index = all.firstIndex(of: angle) else { return 0 }
        return (index - (round * 6) % all.count + all.count) % all.count
    }

    /// The topics in the order the slots take them: each as many times as the creator sends it (one more than it has been sent, at most three),
    /// starting one further each round.
    private func turns(among topics: [IdeaTopic], round: Int) -> [IdeaTopic] {
        let weighted = topics.flatMap { topic -> [IdeaTopic] in
            let score = self.topics[topic.niche?.rawValue ?? topic.label, default: 0]
            return Array(repeating: topic, count: 1 + max(0, min(2, Int((score / Self.sendWeight).rounded(.down)))))
        }
        // Interleaved, so that no topic has three slots in a row: the topic with the most turns first, then the others in turn.
        var queues = topics.map { topic in weighted.filter { $0 == topic } }.filter { !$0.isEmpty }
        var order: [IdeaTopic] = []
        while queues.contains(where: { !$0.isEmpty }) {
            for index in queues.indices where !queues[index].isEmpty { order.append(queues[index].removeFirst()) }
        }
        let shift = round % max(1, order.count)
        return Array(order[shift...] + order[..<shift])
    }
}
