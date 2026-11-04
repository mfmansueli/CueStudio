//
//  ScriptFormatDefinitions.swift
//  Cue Studio
//

import Foundation

/// What each format needs, said to the writer, not only its name: the lines both writers send (Ultra's `UltraFormatGuide`; Apple
/// Intelligence's `ScriptPromptBuilder` when `definesFormats` is on). Built from the app's own blocks (`ScriptType.structure`) and the research
/// behind the Ultra study's rubric (04/11/2026, `tools/ultra/study`): the but/therefore chain for stories, the result first in tutorials,
/// Fact–Myth–Fallacy–Fact (Debunking Handbook 2020) for myths, responsibility and repair first in apologies (Lewicki et al. 2016),
/// hook–problem–product–proof–offer for ads. In the study the definition lifted every setting by 4 to 5 points of 100 over the bare label.
nonisolated enum ScriptFormatDefinitions {
    /// The talking head the creator chose on the dock (it has no `ScriptType`).
    static let talkingHeadLine = "Format chosen by the creator: talking head (one person speaking to camera). It needs one clear point, why it "
        + "matters to this audience, one concrete example, and a close that lands the point."

    /// The format whose blocks an idea of `kind` is written in on Apple Intelligence's device route (`ScriptPromptBuilder.formatGuide(for:)`),
    /// nil for the generic Hook, Body and CTA: only the kinds a format matches. Before it, a card's idea got the creator's usual format
    /// (`FormatGuess` reads English words only), a list of tips for a myth or a how-to in Portuguese.
    static func format(for kind: IdeaAngle) -> ScriptType? {
        switch kind {
        case .story, .lesson: .story
        case .tutorial, .challenge: .tutorial
        case .list: .list
        case .myth: .mythFact
        case .opinion, .prediction: .opinion
        default: nil
        }
    }

    /// The kinds told in the first person as something that happened: they get the story's honesty rule (`ScriptPromptBuilder.storyHonestyRule`).
    static func isLived(_ kind: IdeaAngle) -> Bool {
        [.story, .lesson, .dayInLife, .beforeAfter].contains(kind)
    }

    /// The line for an idea from the cards on Auto, by its kind (`IdeaBrief.angleKind`): the genre it is written as. Nil for a kind with none.
    static func ideaLine(for kind: IdeaAngle) -> String? {
        genres[kind].map { "Format: not chosen by the creator. This idea is \(kind.ask), so write it as \($0)" }
    }

    /// The genre an idea from the cards is written as, by its kind: in the study the kind's definition took Opus at low effort from 89.6 to
    /// 92.6 on 24 card ideas (Format 4.5 to 5.0), while every genre's definition in short, for an idea the creator typed, didn't help (90.9 to
    /// 89.7 on 6): a typed idea keeps reading its genre from the request.
    private static let genres: [IdeaAngle: String] = [
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

    /// The line of a format the creator chose: its name and what it needs.
    static func chosenLine(for type: ScriptType) -> String {
        switch type {
        case .story:
            "Format chosen by the creator: storytime, a story told from their own experience. Open inside the moment of tension, or tease the "
                + "outcome, and make clear early what is at stake. Give only the setup the story needs, then the turn: each beat follows from the "
                + "one before (but, so), never a plain sequence (and then). The payoff answers what the opening promised; any lesson comes out of "
                + "the story in a line or two, never as a list of tips. Show actions and what changed, then stop."
        case .tutorial:
            "Format chosen by the creator: tutorial, a step-by-step how-to. Say the result first (what the viewer will be able to do), then "
                + "distinct steps in order, each a concrete action they can do with what they have, with a way to tell it worked. Name the most "
                + "common mistake where it happens. End when the result is reached."
        case .list:
            "Format chosen by the creator: a list of tips. The hook says what the list solves. Items never overlap, and each gets its why or "
                + "its how with one concrete example. Put the strongest item first or last, and let the transitions carry meaning instead of "
                + "only counting. Close on what to do first."
        case .mythFact:
            "Format chosen by the creator: myth vs fact, one belief busted. Lead with the fact or a hook that frames the belief as wrong; "
                + "state the myth once, flagged as a myth; explain why it seems true and why it misleads; then the fact again, with what to do "
                + "instead. One myth and a few strong reasons, not a pile of arguments."
        case .opinion:
            "Format chosen by the creator: an opinion (a hot take or a reply to a comment). State the position in the first lines and sustain "
                + "it with reasons and one concrete example, not a list of tips. Acknowledge the strongest objection and answer it. Close on the "
                + "position; a question to the audience only when it opens a debate the script built."
        case .review:
            "Format chosen by the creator: a review. The hook and the first impression; what it actually does, with real pros and real cons "
                + "from use; a clear verdict and who it is for (and who should skip it). No specs, prices or tests the request didn't give."
        case .ad:
            "Format chosen by the creator: a sponsored ad (UGC). A hook that sounds like an ordinary video on the platform; the problem the "
                + "viewer knows; the product as the answer; proof (only the brand's facts given, or the creator's own experience told as "
                + "theirs); the offer and the call to action with the brand's link or code; the partnership disclosed. The brand's facts stay "
                + "literal and nothing is promised beyond them."
        case .launch:
            "Format chosen by the creator: a launch or announcement. The news in the first line; what it is, when and where; why it matters "
                + "to this audience; what to do now."
        case .apology:
            "Format chosen by the creator: an apology or statement. Say directly what happened and what the apology is for; take "
                + "responsibility without excuses (the most important part); say sorry; explain only what helps understanding, never as a "
                + "defence; say what will change and how it will be repaired. Sincere and calm: no hype, no jokes, no call to action."
        case .pov:
            "Format chosen by the creator: a POV video. Open with “POV:” and a situation the viewer recognises; speak to the viewer in the "
                + "second person and the present tense, inside one scene built with concrete details; end on a turn or a punchline."
        }
    }
}
