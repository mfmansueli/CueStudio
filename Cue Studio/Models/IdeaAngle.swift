//
//  IdeaAngle.swift
//  Cue Studio
//

import Foundation

/// The way an idea looks at its topic. Asked for six ideas about a topic and told which ones came before, the on-device model copies the list back to
/// the letter (measured on an iPhone 15 Pro: the second batch was the first, word for word). So each batch is given its own order instead: idea one is
/// a list about the first topic, idea two a mistake about the second… (`IdeaSlot`), and the next batch starts further along the angles and the topics;
/// `IdeaTaste` leans the order toward what the creator sends.
nonisolated enum IdeaAngle: String, CaseIterable, Codable, Sendable {
    case list, mistake, myth, story, tutorial, opinion, fact, beforeAfter, beginner, comparison, challenge, dayInLife, tool, lesson, question, prediction

    /// What the model is asked for, in English.
    var ask: String {
        switch self {
        case .list: "a list of things"
        case .mistake: "a common mistake and how to fix it"
        case .myth: "a myth to bust"
        case .story: "a short story from experience"
        case .tutorial: "a quick how-to"
        case .opinion: "an honest opinion"
        case .fact: "a surprising fact"
        case .beforeAfter: "a before and after"
        case .beginner: "the question every beginner asks"
        case .comparison: "a comparison of two options"
        case .challenge: "a challenge to try"
        case .dayInLife: "a day in the life"
        case .tool: "a tool or habit that changed things"
        case .lesson: "a lesson learned the hard way"
        case .question: "a question for the audience"
        case .prediction: "a prediction"
        }
    }

    /// The kind of video as the creator reads it (the starters' own words).
    var kind: String {
        switch self {
        case .list, .tool: String(localized: "List")
        case .mistake, .lesson: String(localized: "Tips")
        case .myth: String(localized: "Myth-busting")
        case .story, .dayInLife: String(localized: "Storytime")
        case .tutorial, .beforeAfter, .challenge: String(localized: "Tutorial")
        case .opinion, .comparison, .prediction, .question: String(localized: "Opinion")
        case .fact, .beginner: String(localized: "Explainer")
        }
    }

    /// How many ideas a batch has.
    static let batchSize = 6

    /// The angles of a batch: `count` consecutive ones, starting further along each round (a whole batch further), so that no two rounds ask the same.
    static func batch(round: Int, count: Int = batchSize) -> [IdeaAngle] {
        let all = allCases
        let start = ((round * batchSize) % all.count + all.count) % all.count
        return (0..<count).map { all[(start + $0) % all.count] }
    }
}
