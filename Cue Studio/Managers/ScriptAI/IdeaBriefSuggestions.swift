//
//  IdeaBriefSuggestions.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// Video ideas as whole briefs (Find inspiration, and the card's ↻): a headline, the angle to take and a first sentence, written together so the
/// three belong to one idea. Only what the creator reads is asked for; the kind of video, its length and its topic come from the slot the idea was
/// asked for (`IdeaSlot`), so the model spends its words on the idea. The lengths keep the whole brief inside the composer's 200 characters
/// (`IdeaBrief.fitted`), which cuts what is still too long at a word.
@Generable
nonisolated struct IdeaBriefSuggestions {
    @Guide(description: "One idea for each numbered request, in the same order.", .count(6))
    var ideas: [Idea]

    @Generable
    nonisolated struct Idea {
        @Guide(description: "The video's title as a creator would post it: specific, natural, at most eight words.")
        var title: String

        @Guide(description: "The angle: one short sentence telling the creator what to do in the video, starting with a verb, at most twelve words.")
        var angle: String

        @Guide(description: "The first sentence the creator says to camera, at most fifteen words. Never a personal story, result or number about the creator.")
        var openingLine: String
    }
}
