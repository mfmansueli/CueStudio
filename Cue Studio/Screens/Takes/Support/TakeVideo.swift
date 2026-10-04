//
//  TakeVideo.swift
//  Cue Studio
//

import Foundation

/// One row of the Takes library: the takes of one script (a freestyle recording stands alone), shown
/// through its best take, at the stage its takes put it in.
nonisolated struct TakeVideo: Hashable, Identifiable, Sendable {
    /// Newest number first.
    let takes: [Take]
    let title: String
    let platform: Platform?
    /// Derived from the takes and the open edits (`TakeStage`), never set by hand.
    var stage: TakeStage = .ready

    var id: String { takes.first?.scriptID?.uuidString ?? takes.first?.id.uuidString ?? "" }

    /// The take marked best, or the newest.
    var best: Take? { takes.first(where: \.isBest) ?? takes.first }

    var hasMarkedBest: Bool { takes.contains(where: \.isBest) }

    /// The most recent recording decides where the video sits (Today, Yesterday, Earlier).
    var latest: Take? { takes.max { $0.recordedAt < $1.recordedAt } }

    var isEdited: Bool { takes.contains(where: \.isEdited) }

    /// None of its takes was saved or shared yet.
    var isNotShared: Bool { !takes.contains(where: \.isExported) }

    /// "3 takes · Best: Take 3"
    var takesLabel: String? {
        guard takes.count > 1 else { return nil }
        let count = String(localized: "\(takes.count) takes")
        guard hasMarkedBest, let best else { return count }
        return count + " · " + String(localized: "Best: \(best.label)")
    }
}
