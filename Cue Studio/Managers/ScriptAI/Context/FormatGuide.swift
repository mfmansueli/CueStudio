//
//  FormatGuide.swift
//  Cue Studio
//

import Foundation

/// What the AI is told about the shape of the video: the format's name, its blocks in order and what each block is for, in English whatever the
/// interface language is (the names the creator reads are translated and don't belong in the prompt). With no format chosen the shape is the
/// generic one, or the one `FormatGuess` found.
nonisolated struct FormatGuide: Hashable, Sendable {
    /// "tutorial", "talking video".
    let name: String
    /// Block names in order, as the AI writes them.
    let blocks: [String]
    /// What each block is for, one line, in the same order.
    let purposes: [String]

    /// "Hook → Promise → Steps → CTA"
    var order: String { blocks.joined(separator: " → ") }

    /// "Hook: …. Promise: …." the line that says what each block does.
    var purpose: String {
        zip(blocks, purposes).map { "\($0): \($1)" }.joined(separator: " ")
    }

    /// The name of the closing block of a script that asks the viewer for nothing.
    static let closeBlock = "Close"

    /// The shape with its "CTA" block as the creator ends (the owner's B1 and B11, 02/11/2026): a "Close" that asks for nothing when they never
    /// ask, or usually don't; the action they usually ask for, and no other, when they have one. Without an ending of theirs it stays as it is.
    func ending(for voice: CreatorVoice?) -> FormatGuide {
        guard let voice, voice.decidesTheEnding, let index = blocks.firstIndex(of: "CTA") else { return self }
        var blocks = blocks
        var purposes = purposes
        let theirs = voice.endingActions.joined(separator: " or ")
        if voice.endsWithoutAsking {
            blocks[index] = Self.closeBlock
            // Measured on an iPhone 18 Pro Max (02/11/2026): "ask the viewer to do nothing" came back as "Nothing to do." and "the takeaway
            // is this:", the instruction's own words read out. Neither word is in it now.
            purposes[index] = theirs.isEmpty
                ? "finish on the point itself, in a line worth remembering, with no request to the viewer."
                : "finish on the point itself, \(theirs), with no request to the viewer."
        } else {
            purposes[index] = "the creator's own ending: \(theirs). Ask for nothing else."
        }
        return FormatGuide(name: name, blocks: blocks, purposes: purposes)
    }

    static let generic = FormatGuide(
        name: "talking video", blocks: ["Hook", "Body", "CTA"],
        purposes: [
            "grab attention in 3 seconds with the main promise.",
            "explain the one idea in small, concrete steps.",
            "one clear action.",
        ]
    )

    static let talkingHead = FormatGuide(
        name: "talking head", blocks: ["Hook", "Point", "Why it matters", "CTA"],
        purposes: [
            "open on the requested subject.", "state one clear point.",
            "explain why it matters to this audience.", "close in the way the request asks for, without forcing engagement.",
        ]
    )

    static func guide(for type: ScriptType?) -> FormatGuide {
        guard let type else { return .generic }
        switch type {
        case .ad:
            return FormatGuide(
                name: "sponsored ad", blocks: ["Hook", "Problem", "Product", "Proof", "Offer"],
                purposes: [
                    "stop the scroll.",
                    "name one real problem.",
                    "show how the product solves it.",
                    "only facts from the brief.",
                    "the offer and how to get it.",
                ]
            )
        case .review:
            return FormatGuide(
                name: "review", blocks: ["Hook", "First look", "Pros & cons", "Verdict"],
                purposes: [
                    "the question the viewer has.",
                    "what it is and what you notice first.",
                    "two honest pros and one honest con.",
                    "who it is for, in one line.",
                ]
            )
        case .tutorial:
            return FormatGuide(
                name: "tutorial", blocks: ["Hook", "Promise", "Steps", "CTA"],
                purposes: [
                    "show the result or the problem.",
                    "say exactly what they will be able to do.",
                    "one action per step, concrete.",
                    "ask them to save it or try step one.",
                ]
            )
        case .list:
            return FormatGuide(
                name: "list of tips", blocks: ["Hook", "Tips", "CTA"],
                purposes: [
                    "say how many tips and what they give.",
                    "each tip is one sentence plus one reason.",
                    "ask them to save it or share their own tip.",
                ]
            )
        case .story:
            return FormatGuide(
                name: "storytime", blocks: ["Hook", "Setup", "Twist", "Payoff"],
                purposes: [
                    "the most surprising line first.",
                    "where, when and who, briefly.",
                    "the one thing that went differently.",
                    "what it meant, in a line the viewer remembers.",
                ]
            )
        case .opinion:
            return FormatGuide(
                name: "hot take or reply", blocks: ["Hook", "Take", "Why", "Question"],
                purposes: [
                    "say the take is unpopular or asked for.",
                    "state the take plainly in one sentence.",
                    "two reasons and one example.",
                    "ask a real question that invites a reply.",
                ]
            )
        case .launch:
            return FormatGuide(
                name: "announcement", blocks: ["Hook", "News", "Details", "CTA"],
                purposes: [
                    "tease that something is here.",
                    "the news in one sentence.",
                    "what it is, who it is for, when.",
                    "one clear next step.",
                ]
            )
        case .apology:
            return FormatGuide(
                name: "apology or statement", blocks: ["Opening", "Acknowledge", "Own it", "What changes", "Closing"],
                purposes: [
                    "say what this is about, directly.",
                    "name what happened, plainly.",
                    "take responsibility without excuses.",
                    "what will be different, concretely.",
                    "a short, sincere close.",
                ]
            )
        case .mythFact:
            return FormatGuide(
                name: "myth vs fact", blocks: ["Myth", "Why people think it", "Fact", "CTA"],
                purposes: [
                    "say the myth the way people say it.",
                    "be fair about why it sounds true.",
                    "the correction plus one piece of proof.",
                    "ask them to share it with someone who believes it.",
                ]
            )
        case .pov:
            return FormatGuide(
                name: "POV", blocks: ["POV line", "Scene", "Twist"],
                purposes: [
                    "one line that starts with “POV:”.",
                    "second person, present tense, concrete details.",
                    "an unexpected turn in the last line.",
                ]
            )
        }
    }
}
