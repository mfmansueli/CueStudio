//
//  ThemeSuggestions.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// New video ideas for the creator's niche ("New ideas" in Generate › Themes).
@Generable
nonisolated struct ThemeSuggestions {
    @Guide(description: "Six video ideas for the creator's niche.", .count(6))
    var ideas: [Idea]

    @Generable
    nonisolated struct Idea {
        @Guide(description: "The video idea as a catchy title, at most nine words.")
        var title: String

        @Guide(description: "The kind of video in one or two words: List, Tutorial, Storytime, Explainer, Opinion, Routine or Review.")
        var kind: String

        @Guide(description: "Length in minutes: 1 or 2.", .range(1...2))
        var minutes: Int

        @Guide(description: "Which of the creator's niches this idea belongs to, exactly as given.")
        var niche: String
    }
}
