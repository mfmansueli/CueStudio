//
//  StyleReading.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// What Apple Intelligence says of a creator's writing: only choices from Cue's own lists, so it can't make up a tone or a topic. The ones that
/// aren't on the lists are dropped when the answer is read (`WritingImportProposalBuilder`).
@Generable
nonisolated struct StyleReading {
    @Guide(
        description: "How the writer sounds, the one or two that fit best: casual is conversational, professional is straight to the point, "
            + "warmCalm is warm and calm, funny is playful, dry is dry and sarcastic.",
        .maximumCount(2),
        .element(.anyOf(["casual", "professional", "educational", "confident", "warmCalm", "energetic", "funny", "dry"]))
    )
    var tones: [String]

    @Guide(
        description: "What the writer's videos are about: the one to three that fit best.", .maximumCount(3),
        .element(.anyOf([
            "fitness", "food", "beauty", "fashion", "finance", "tech", "travel", "productivity", "parenting", "lifestyle",
            "gaming", "realEstate", "musicArts", "pets", "homeDIY", "healthcare", "business", "study", "relationships", "faith", "news",
            "cars", "sports", "languages", "booksMovies",
        ]))
    )
    var topics: [String]

    @Guide(
        description: "Who the writer talks to, or unclear when the texts don't say.",
        .anyOf(["teens", "students", "youngAdults", "parents", "professionals", "businessOwners", "localCommunity", "insiders", "unclear"])
    )
    var audience: String

    @Guide(description: "How much humor the writer uses.", .anyOf(["none", "little", "lot"]))
    var humor: String
}
