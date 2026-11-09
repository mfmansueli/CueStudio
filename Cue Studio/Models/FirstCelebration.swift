//
//  FirstCelebration.swift
//  Cue Studio
//

import Foundation

/// D4 · the first celebration (owner, 09/11/2026): the first journey has at most one full screen.
///
/// - Posting confirmed right away ("Posted on TikTok?" → Yes): the send-off is the celebration. It tells the first star and offers the milestone
///   icon in a row of its own (Aurora with the first post), with no story before or after it.
/// - Leaving the review without a confirmed post: no full screen; the first star lights quietly on that video in Takes.
/// - A post confirmed later (another session) gets the same send-off, with the icon when it is due; the milestones (1, 10, 25, 50) count
///   confirmed posts across the creator's life. Saving to Photos finishes an export (and spends a free one), but is not a post.
nonisolated enum FirstCelebration {
    /// What is true as a review is left without a confirmed post.
    struct LeavingFacts: Equatable {
        /// The first flight is over (the review isn't the flight's own).
        var flightDone: Bool
        var firstStarShown: Bool
        /// Settings › Personalize › Celebrations.
        var celebrations: Bool
        /// A video brought in from Photos was never recorded here: it lights no first star.
        var takeIsImported: Bool
        /// Videos recorded with Cue (takes grouped as Takes groups them): the first star is the first video's.
        var recordedVideos: Int
        /// Posts the creator confirmed, ever.
        var confirmedPosts: Int
    }

    /// The send-off after a confirmed post: the first star when this post is the first, of the first video recorded with Cue (`isFirstVideo`:
    /// not imported, and no other video recorded), and the star is untold; the milestone icon due now.
    static func sendOff(firstStarShown: Bool, isFirstVideo: Bool, confirmedPosts: Int, dueMilestone: Int?) -> SendOffMoment {
        SendOffMoment(isFirstStar: !firstStarShown && isFirstVideo && confirmedPosts == 1, milestone: dueMilestone)
    }

    /// Whether Takes keeps the first star for the take whose review was just left.
    static func takesKeepsFirstStar(_ facts: LeavingFacts) -> Bool {
        facts.flightDone && !facts.firstStarShown && facts.celebrations && !facts.takeIsImported
            && facts.recordedVideos == 1 && facts.confirmedPosts == 0
    }

    /// Videos among `takes` recorded with Cue: a script's takes are one video, a freestyle take one of its own (as in Takes).
    static func recordedVideos(in takes: [Take]) -> Int {
        Set(takes.filter { !$0.isImported }.map { $0.scriptID?.uuidString ?? $0.id.uuidString }).count
    }
}
