//
//  IdeaIngredientList.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// One kind of a topic's ingredients (`IdeaIngredientKind`) as Private Cloud Compute lists them, one request a kind: asked all at once, the four
/// lists of a fitness topic were refused by the guardrails in three languages of five over its beliefs (diets), and the other three went with
/// them. The guide describes without examples: an example in English is one the model may hand back untranslated.
@Generable
nonisolated struct IdeaIngredientList {
    @Guide(description: "All different, each a short phrase of two to seven words.", .count(8))
    var items: [String]
}
