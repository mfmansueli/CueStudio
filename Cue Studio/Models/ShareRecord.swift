//
//  ShareRecord.swift
//  Cue Studio
//

import Foundation

/// One video that left Cue (9.2, `09` "Data"): which take, when, to which platforms and from which topic. A year's universe is built from these. A
/// video counts once, however many networks it goes to (each network adds one to its planet). The ones shared before records existed have only the
/// take: their date, platform and topic are read from the take.
nonisolated struct ShareRecord: Codable, Hashable, Sendable {
    let takeID: UUID
    var date: Date?
    /// The networks it was confirmed live on, in the order they were confirmed.
    var platforms: [Platform]
    var topic: String?

    init(takeID: UUID, date: Date?, platforms: [Platform] = [], topic: String?) {
        self.takeID = takeID
        self.date = date
        self.platforms = platforms
        self.topic = topic
    }

    private enum CodingKeys: String, CodingKey {
        case takeID, date, platforms, topic
        /// An earlier build kept one platform.
        case platform
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        takeID = try container.decode(UUID.self, forKey: .takeID)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        if let platforms = try? container.decodeIfPresent([Platform].self, forKey: .platforms) {
            self.platforms = platforms
        } else if let platform = try? container.decodeIfPresent(Platform.self, forKey: .platform) {
            platforms = [platform]
        } else {
            platforms = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(takeID, forKey: .takeID)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encode(platforms, forKey: .platforms)
        try container.encodeIfPresent(topic, forKey: .topic)
    }
}
