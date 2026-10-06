//
//  UniverseVideo.swift
//  Cue Studio
//

import Foundation

/// A `ShareRecord` with its blanks filled in: the date, platform and topic the universe draws. A video shared before records existed takes them
/// from its take; one whose take is gone keeps the day of the first share.
nonisolated struct UniverseVideo: Hashable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    /// The networks it went to: each adds one to its planet.
    let platforms: [Platform]
    let topic: String?
    /// The take is still in the library (a dot opens it).
    let hasTake: Bool

    init(record: ShareRecord, take: Take?, script: Script?, fallbackDate: Date) {
        id = record.takeID
        date = record.date ?? take?.recordedAt ?? fallbackDate
        platforms = record.platforms.isEmpty ? (take?.platform.map { [$0] } ?? []) : record.platforms
        topic = record.topic ?? script?.topic
        hasTake = take != nil
    }

    init(id: UUID = UUID(), date: Date, platform: Platform? = nil, platforms: [Platform] = [], topic: String? = nil, hasTake: Bool = true) {
        self.id = id
        self.date = date
        self.platforms = platforms.isEmpty ? (platform.map { [$0] } ?? []) : platforms
        self.topic = topic
        self.hasTake = hasTake
    }

    func isIn(year: Int, calendar: Calendar = .current) -> Bool { calendar.component(.year, from: date) == year }

    /// Every record of the shared videos, with the blanks read from the takes and scripts that are still in the library.
    static func resolve(records: [ShareRecord], takes: [Take], scripts: [Script], fallbackDate: Date) -> [UniverseVideo] {
        let takeByID = Dictionary(takes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let scriptByID = Dictionary(scripts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return records.map { record in
            let take = takeByID[record.takeID]
            return UniverseVideo(record: record, take: take, script: take?.scriptID.flatMap { scriptByID[$0] }, fallbackDate: fallbackDate)
        }
    }
}
