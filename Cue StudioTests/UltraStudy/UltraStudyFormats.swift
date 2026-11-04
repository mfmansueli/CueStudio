//
//  UltraStudyFormats.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// What each format needs, as the study's `formatFull` variant tells the writer in place of the app's one-line label ("Format chosen by the
/// creator: storytimes."). Built from the app's own blocks (`ScriptType.structure`) and the research behind the study's rubric: the
/// but/therefore chain for stories, the result first in tutorials, Fact–Myth–Fallacy–Fact (Debunking Handbook 2020) for myths, responsibility
/// and repair first in apologies (Lewicki et al. 2016), hook–problem–product–proof–offer for ads.
nonisolated enum UltraStudyFormats {
    /// The line that replaces the app's label for `choice`; nil for Auto (nothing to define).
    static func line(for choice: FormatChoice) -> String? {
        switch choice {
        case .auto: nil
        case .talkingHead:
            "Format chosen by the creator: talking head (one person speaking to camera). It needs one clear point, why it matters to this "
                + "audience, one concrete example, and a close that lands the point."
        case .type(let type): line(for: type)
        }
    }

    private static func line(for type: ScriptType) -> String {
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
