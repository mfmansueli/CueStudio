//
//  IdeaEcho.swift
//  Cue Studio
//

import Foundation

/// What is remembered of an idea to tell it apart from the next ones (`IdeaSimilarity.repeats`): the words of its headline, of its angle and of
/// the start of its opening line, and which of the creator's topics it is about. Small, so the last few dozen are kept between sessions.
nonisolated struct IdeaEcho: Codable, Hashable, Sendable {
    var title: Set<String>
    var angle: Set<String>
    var opening: Set<String>
    /// `IdeaTaste.topicKey`-style key of the topic; nil when not known.
    var topic: String?

    init(title: Set<String>, angle: Set<String> = [], opening: Set<String> = [], topic: String? = nil) {
        self.title = title
        self.angle = angle
        self.opening = opening
        self.topic = topic
    }

    init(_ idea: ThemeIdea) {
        let brief = idea.brief
        self.init(
            title: IdeaSimilarity.words(in: idea.title),
            angle: IdeaSimilarity.words(in: brief?.angle ?? ""),
            opening: IdeaSimilarity.words(in: IdeaSimilarity.firstSentence(of: brief?.openingLine ?? "")),
            topic: brief?.topicKey ?? idea.topic ?? idea.niche.rawValue
        )
    }

    /// An idea remembered only by its title (what older versions kept).
    init(title: String) {
        self.init(title: IdeaSimilarity.words(in: title))
    }
}
