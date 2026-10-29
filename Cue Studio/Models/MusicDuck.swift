//
//  MusicDuck.swift
//  Cue Studio
//

import Foundation

/// How far a music clip goes down while someone speaks (Volume › Lower under voice), and what it does in the pauses. Music added
/// since these settings has them (`standard`: 12 dB, staying low in pauses); a clip saved before has none (`MusicClip.duck` nil)
/// and keeps the first way, 12 dB down and back after about a second of quiet along straight ramps, so it sounds as it did
/// until its lowering is touched.
nonisolated struct MusicDuck: Codable, Hashable, Sendable {
    /// Decibels it can go down by: a little (3) to almost silent (30).
    static let depthRange: ClosedRange<Double> = 3...30
    static let standard = MusicDuck(depth: 12, pauses: .staysLow)

    /// Decibels the music goes down by while someone speaks.
    var depth: Double
    var pauses: MusicDuckPauses

    /// The music's volume under the voice, as a factor of its own (12 dB: about a quarter).
    var level: Double { pow(10, -min(max(depth, Self.depthRange.lowerBound), Self.depthRange.upperBound) / 20) }

    init(depth: Double, pauses: MusicDuckPauses) {
        self.depth = depth
        self.pauses = pauses
    }

    private enum CodingKeys: String, CodingKey { case depth, pauses }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        depth = (try? container.decodeIfPresent(Double.self, forKey: .depth)) ?? Self.standard.depth
        pauses = container.decodeChoice(MusicDuckPauses.self, forKey: .pauses, unknown: .fallback, report: decoder.decodingReport)
            ?? Self.standard.pauses
    }
}
