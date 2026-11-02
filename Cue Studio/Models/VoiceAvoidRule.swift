//
//  VoiceAvoidRule.swift
//  Cue Studio
//

import Foundation

/// What "Never write…" means for one of the things Cue offers to avoid: the sentence the AI is given (the thing to avoid and what to do instead)
/// and the words the checker looks for after the script is written. What the creator typed has no rule of its own: it is told to the AI as it
/// is and looked for as it is.
nonisolated struct VoiceAvoidRule: Hashable, Sendable {
    /// The English id the answer is kept under (`VoiceQuestion.avoidOptions`).
    let id: String
    /// What the AI reads, in the positive and the negative.
    let instruction: String
    /// Lowercase phrases whose presence breaks the rule (English; a typed rule is looked for in any language).
    let terms: [String]
    /// The rule is broken by any emoji.
    let forbidsEmoji: Bool
    /// The rule is broken by an ending that asks the viewer to do something (`WritingOpeningReader.endings`, in the script's language).
    let forbidsCallToAction: Bool

    private init(_ id: String, _ instruction: String, terms: [String] = [], forbidsEmoji: Bool = false, forbidsCallToAction: Bool = false) {
        self.id = id
        self.instruction = instruction
        self.terms = terms
        self.forbidsEmoji = forbidsEmoji
        self.forbidsCallToAction = forbidsCallToAction
    }

    /// The "never" of an ending (the owner's B11, 02/11/2026): "How you usually end" is a habit, this is a rule.
    static let callsToActionID = "Calls to action"

    static let known: [VoiceAvoidRule] = [
        VoiceAvoidRule(
            "Clickbait", "no clickbait (“you won't believe…”, “what happens next”): say the real point up front",
            terms: ["you won't believe", "you won’t believe", "wait until you see", "what happens next", "doctors hate", "shocking truth", "blow your mind"]
        ),
        VoiceAvoidRule(
            "Hype words", "no hype words (game-changer, insane, mind-blowing, unbelievable): use plain, specific words",
            terms: [
                "game-changer", "game changer", "insane", "mind-blowing", "mind blowing", "unbelievable", "life-changing", "life changing",
                "revolutionary", "next level", "jaw-dropping",
            ]
        ),
        VoiceAvoidRule("Emojis in captions", "no emojis: words only", forbidsEmoji: true),
        VoiceAvoidRule(
            "Medical claims", "no medical claims: never say something cures, treats or heals, and speak in general terms",
            terms: ["cures ", "cure your", "heals ", "heal your", "treats your", "guaranteed to", "clinically proven", "miracle"]
        ),
        VoiceAvoidRule(
            "Politics", "no politics: no parties, politicians, elections or political opinions",
            terms: ["democrat", "republican", "liberal", "conservative", "election", "vote for", "left-wing", "right-wing", "political party"]
        ),
        VoiceAvoidRule(
            "Exaggerated promises", "no exaggerated promises: no guaranteed results or “overnight” claims, keep claims modest and checkable",
            terms: ["guaranteed", "overnight", "get rich", "never fail", "always works"]
        ),
        VoiceAvoidRule(
            "False urgency", "no false urgency (“last chance”, “act now”, “only today”)",
            terms: ["last chance", "act now", "only today", "limited time", "don't miss out", "don’t miss out", "hurry"]
        ),
        VoiceAvoidRule("Naming competitors", "never name competitors or rival brands"),
        VoiceAvoidRule(
            callsToActionID,
            "no calls to action: never ask viewers to follow, like, comment, subscribe, save, share or go to a link; end on the point itself",
            forbidsCallToAction: true
        ),
    ]

    /// The rule for something the creator picked (its English id), nil for what they typed.
    static func rule(for stored: String) -> VoiceAvoidRule? {
        known.first { VoiceTextValidator.key($0.id) == VoiceTextValidator.key(stored) }
    }

    /// What the AI reads for one thing to avoid.
    static func instruction(for stored: String) -> String {
        rule(for: stored)?.instruction ?? "never write “\(stored)”"
    }
}
