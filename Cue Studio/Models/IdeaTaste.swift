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
        return (index - (round * IdeaAngle.batchSize) % all.count + all.count) % all.count
    }

    /// The topics in the order the slots take them: each as many times as the creator sends it (one more than it has been sent, at most three),
    /// starting one further each round.
    private func turns(among topics: [IdeaTopic], round: Int) -> [IdeaTopic] {
        let weighted = topics.flatMap { topic -> [IdeaTopic] in
            let score = self.topics[Self.topicKey(of: topic), default: 0]
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
