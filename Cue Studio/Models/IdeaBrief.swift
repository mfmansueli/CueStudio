//
//  IdeaBrief.swift
//  Cue Studio
//

import Foundation

/// One inspiration as one creative brief (Find inspiration): what the video is about, the angle that makes it worth watching, and a first
/// sentence that lets the creator hear it at once. The three are written together and travel together, from the roulette's card to the
/// composer and on to the script, so the script follows the angle and opens with (or near) the line instead of inventing its own.
///
/// The opening line is a suggestion to say, never a claim about the creator: no lived experience, result or number is put in their mouth.
nonisolated struct IdeaBrief: Hashable, Codable, Sendable {
    /// What the video is about, in a few words ("Desk stretches").
    var subject: String
    /// The perspective that makes it interesting, as a phrase that follows the subject ("the 3 stretches people skip, and why they matter").
    var angle: String
    /// A first sentence the creator could say ("If your back hurts by 3 p.m., this one’s for you.").
    var openingLine: String
    /// The subtopic of the creator's topic it is about, when it is one ("Yoga & stretching").
    var subtopic: String?
    /// The language it is written in (a minimal identifier, "en"), when known.
    var language: String?

    /// What "Use this idea" puts in the composer: the whole brief, as text the creator can change. Never longer than the composer takes
    /// (`IdeaPromptDraft.maxCharacters`).
    var composerText: String {
        let line = String(localized: "\(subject): \(angle)\nOpen with: “\(openingLine)”")
        return String(line.prefix(IdeaPromptDraft.maxCharacters))
    }

    /// What of the brief still stands in `text`, the composer's text when it is sent: the creator may have changed the idea, and what they
    /// wrote always wins over what the card said. Nil when the subject is gone (the idea took another direction); the angle or the opening
    /// line are left empty when their words are gone.
    func standing(in text: String) -> IdeaBrief? {
        guard Self.contains(text, subject) else { return nil }
        var kept = self
        if !Self.contains(text, angle) { kept.angle = "" }
        if !Self.contains(text, openingLine) { kept.openingLine = "" }
        return kept
    }

    /// `part` is still in `text`, case, accents and punctuation aside.
    private static func contains(_ text: String, _ part: String) -> Bool {
        let fold = { (value: String) in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let needle = fold(part)
        return !needle.isEmpty && fold(text).contains(needle)
    }
}
