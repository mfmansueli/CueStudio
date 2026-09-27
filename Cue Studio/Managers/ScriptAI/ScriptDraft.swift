//
//  ScriptDraft.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// What the model returns when it writes a script (guided generation), so Cue never has to parse
/// headings or labels out of free text.
@Generable
nonisolated struct ScriptDraft {
    @Guide(description: "A short, specific title for the video, at most eight words, no quotes or emojis.")
    var title: String

    @Guide(description: "The script in speaking order, one entry per block of the requested structure.")
    var blocks: [Block]

    @Guide(description: "True when the script states facts a viewer could check, such as history, science, dates, names or numbers.")
    var statesFacts: Bool

    @Generable
    nonisolated struct Block {
        @Guide(description: "The block name from the requested structure, for example Hook, Body or CTA.")
        var label: String

        @Guide(description: "Exactly what the creator says in this block, in the first person, with short stage cues in square brackets such as [pause], [smile], [emphasis], [confident] or [look at camera].")
        var text: String
    }

    /// Paragraphs separated by blank lines, the format the prompter reads.
    var scriptText: String {
        blocks.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
