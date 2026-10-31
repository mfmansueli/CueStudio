//
//  IdeaSignals.swift
//  Cue Studio
//

import Foundation

/// What the ideas may be tied to (`IdeaTie`), read from what the creator did and where they live: the videos they shared, the comments their
/// scripts answered and the occasions coming up.
nonisolated struct IdeaSignals: Hashable, Sendable {
    /// The titles of the scripts behind the videos they shared, the newest first.
    var posted: [String] = []
    /// The comments their scripts answered, the newest first.
    var comments: [String] = []
    /// The occasions near today where they live, the nearest first (`IdeaCalendar`).
    var occasions: [IdeaOccasion] = []

    /// How many of the newest videos and comments the ideas follow up, in turn.
    static let recent = 3

    /// The videos and comments to follow up, from the share records and the library (the occasions are worked out apart, once a day).
    static func read(records: [ShareRecord], takes: [Take], scripts: [Script]) -> IdeaSignals {
        let scriptByID = Dictionary(scripts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let takeByID = Dictionary(takes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var posted: [String] = []
        for record in records.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) {
            guard let scriptID = takeByID[record.takeID]?.scriptID, let title = scriptByID[scriptID]?.title else { continue }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !posted.contains(trimmed) { posted.append(trimmed) }
        }
        let comments = scripts.sorted { $0.updatedAt > $1.updatedAt }.compactMap { $0.comment?.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return IdeaSignals(posted: Array(posted.prefix(recent)), comments: Array(comments.prefix(recent)))
    }

    /// The slots of a round with at most one tie each: an occasion every other round, a follow-up of a shared video in the rounds between, and a
    /// comment's next question every third round, each on its own slot and taking the next of its kind in turn. Never all six: the rest of the
    /// batch is the creator's topics as they are.
    func tie(_ slots: [IdeaSlot], round: Int) -> [IdeaSlot] {
        var tied = slots
        func take(_ index: Int, _ tie: IdeaTie) { if tied.indices.contains(index) { tied[index].tie = tie } }
        if round % 2 == 0, !occasions.isEmpty { take(1, .occasion(occasions[(round / 2) % occasions.count])) }
        if round % 2 == 1, !posted.isEmpty { take(0, .followUp(posted[(round / 2) % posted.count])) }
        if round % 3 == 2, !comments.isEmpty { take(2, .comment(comments[(round / 3) % comments.count])) }
        return tied
    }
}
