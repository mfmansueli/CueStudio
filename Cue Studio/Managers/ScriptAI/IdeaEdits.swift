//
//  IdeaEdits.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// What Private Cloud Compute answers when it edits a batch of the iPhone model's ideas outside English (`ScriptPromptBuilder.ideaEditPrompt`):
/// for each, whether it is worth keeping, and its words as a native creator would write them. The iPhone's model has the ideas; written in
/// another language, it renders English word for word ("a comida engorda de viagem"), and the larger model writes the language as it is spoken.
@Generable
nonisolated struct IdeaEdits {
    @Guide(description: "One for each idea, in the same order.")
    var ideas: [Edit]

    @Generable
    nonisolated struct Edit {
        @Guide(description: "False only when the idea makes no sense, is not about its topic, or nobody would want to watch it.")
        var keep: Bool

        @Guide(description: "The title as a native creator would post it: specific, natural, at most eight words.")
        var title: String

        @Guide(description: "One short sentence telling the creator what to do in the video, starting with a verb, at most twelve words.")
        var angle: String

        @Guide(description: "The first sentence the creator says to camera, at most fifteen words.")
        var openingLine: String
    }

    /// Each idea's edit, nil for one dropped (`IdeaBriefReader.edited`).
    var answers: [IdeaBriefReader.Answer?] {
        ideas.map { edit in
            edit.keep ? IdeaBriefReader.Answer(title: edit.title, angle: edit.angle, openingLine: edit.openingLine) : nil
        }
    }
}
