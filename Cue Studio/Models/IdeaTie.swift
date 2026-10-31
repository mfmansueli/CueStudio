//
//  IdeaTie.swift
//  Cue Studio
//

import Foundation

/// What an idea is tied to besides its topic and angle, and what the card tells the creator it came from: a day coming up where they live, a
/// video they posted (the idea follows it up), or a comment from their audience they answered (the idea answers what that audience asks next).
nonisolated enum IdeaTie: Hashable, Codable, Sendable {
    case occasion(IdeaOccasion)
    /// The title of the script behind a video they shared.
    case followUp(String)
    /// The text of a comment one of their scripts answered.
    case comment(String)

    /// The most of a comment or a title the model reads.
    static let quoteLimit = 140

    /// What the card says the idea came from, under it.
    var cardLine: String {
        switch self {
        case .occasion(let occasion):
            String(localized: "Coming up: \(occasion.name)", comment: "Under an idea tied to an occasion coming up where the creator lives")
        case .followUp(let title):
            String(localized: "Follows up your video “\(Self.shortened(title))”", comment: "Under an idea that follows up a video the creator shared; its title")
        case .comment:
            String(localized: "From a comment you answered", comment: "Under an idea grown from an audience comment one of the creator's scripts answered")
        }
    }

    /// The most of a video's title the card shows.
    static let cardTitleLimit = 48

    private static func shortened(_ title: String) -> String {
        guard title.count > cardTitleLimit else { return title }
        let cut = title.prefix(cardTitleLimit)
        let atWord = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
        return atWord.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// How the slot asks for it, after "a quick how-to about beauty and skincare".
    var promptClause: String {
        switch self {
        case .occasion(let occasion):
            ", tied to \(occasion.promptName), \(occasion.promptWhen)"
        case .followUp(let title):
            ", as a follow-up to their video “\(title.prefix(Self.quoteLimit))” (a part two, the next step or the question it left open)"
        case .comment(let text):
            ", answering what their audience would ask next after this comment they already answered: “\(text.prefix(Self.quoteLimit))”"
        }
    }
}
