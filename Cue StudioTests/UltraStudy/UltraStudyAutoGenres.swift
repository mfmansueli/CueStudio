//
//  UltraStudyAutoGenres.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// What the study's `autoFull` variant tells the writer on Auto, in place of the app's "Format: not chosen. Read the genre from the request…":
/// an idea from the cards (its kind known) gets that kind's definition, the way `formatFull` defines a chosen format; a typed idea gets every
/// genre's definition in short, to choose one and follow it in the same call (the owner's idea, 04/11/2026: choose the format first, then
/// write it to its definition, without a call of its own).
nonisolated enum UltraStudyAutoGenres {
    /// The genre each kind of idea is written as, with what it needs (the rubric's "Auto, by the idea's kind" and the format checklists).
    static let definitions: [IdeaAngle: String] = [
        .story: "a story told from their own experience. Open inside the moment of tension, or tease the outcome, and make clear early what is "
            + "at stake. Give only the setup the story needs, then the turn: each beat follows from the one before (but, so), never a plain "
            + "sequence (and then). The payoff answers what the opening promised; any lesson comes out of the story in a line or two, never as "
            + "a list of tips.",
        .lesson: "the story of learning a lesson the hard way: the moment it went wrong, what it cost, the turn where they understood, and the "
            + "lesson in a line or two at the end, never as a list of tips.",
        .dayInLife: "a day in the life, shown as a day: concrete moments in order (the hours of the task or the day), each with one detail and "
            + "why it matters, a small surprise or turn, and a close on what the day adds up to. Never a list of tips.",
        .tutorial: "a quick how-to. Say the result first (what the viewer will be able to do), then distinct steps in order, each a concrete "
            + "action with what they have, with a way to tell it worked; name the most common mistake where it happens; end when the result "
            + "is reached.",
        .challenge: "a challenge to try: the challenge and its rule first, how to do it step by step, what to notice while doing it, and the "
            + "invitation to try it.",
        .list: "a list of tips. The hook says what the list solves; items never overlap, each with its why or its how and one concrete example; "
            + "the strongest first or last; transitions that carry meaning instead of only counting; close on what to do first.",
        .tool: "one tool or habit that changed things: the problem before it, what it is and how it is used, the concrete change it made, and "
            + "who it suits (and who it doesn't).",
        .mistake: "one common mistake: the mistake as people actually make it, why it happens, what it costs, and the fix with a way to check it "
            + "worked. One mistake developed, not a list.",
        .myth: "myth vs fact, one belief busted. Lead with the fact or a hook that frames the belief as wrong; state the myth once, flagged as a "
            + "myth; explain why it seems true and why it misleads; then the fact again, with what to do instead.",
        .opinion: "an opinion. State the position in the first lines and sustain it with reasons and one concrete example, not a list of tips. "
            + "Acknowledge the strongest objection and answer it. Close on the position.",
        .question: "a question for the audience: the question and why it matters to them, the creator's own answer with one example, and an "
            + "invitation to answer that the script built.",
        .beginner: "the question every beginner asks: the question in their words, the direct answer early, the why with one concrete example, "
            + "and the one caveat that matters.",
        .fact: "a surprising fact, explained: the fact stated plainly early, why it is true (the mechanism in everyday words, no invented "
            + "numbers), one concrete example, and what it changes for the viewer.",
        .beforeAfter: "a before and after: the before shown concretely (a scene or a routine), the turning point, the after with the same "
            + "details so the contrast shows, and what made the difference. Not a list of tips.",
        .comparison: "a comparison of two options: both named early, the criteria that matter to this audience, each option weighed on them "
            + "with an example, and a clear verdict by situation (who should pick which).",
        .prediction: "a prediction: the claim early, the signs and reasons behind it (no invented statistics), the strongest counterargument "
            + "answered, and what the viewer should do now.",
    ]

    /// The genres a typed idea chooses from, each with its definition.
    private static let menu: [(name: String, kind: IdeaAngle)] = [
        ("Story", .story), ("Lesson learned", .lesson), ("Day in the life", .dayInLife), ("Tutorial", .tutorial), ("List", .list),
        ("One mistake", .mistake), ("Myth vs fact", .myth), ("Opinion", .opinion), ("Explained fact", .fact), ("Before and after", .beforeAfter),
        ("Comparison", .comparison), ("Prediction", .prediction),
    ]

    /// The line for an idea of `angle`, or every genre's definition when the idea was typed (nil).
    static func line(for angle: IdeaAngle?) -> String {
        if let angle, let definition = definitions[angle] {
            return "Format: not chosen by the creator. This idea is \(angle.ask), so write it as \(definition)"
        }
        let genres = menu.compactMap { item in definitions[item.kind].map { "- \(item.name): \($0)" } }
        let lead = "Format: not chosen. First decide which one genre this request asks for (a list only when the request is a list; the "
            + "creator's usual formats only help when the request is vague), then write it to that genre's needs:"
        return ([lead] + genres).joined(separator: "\n")
    }
}
