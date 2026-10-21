//
//  VoiceReach.swift
//  Cue Studio
//

import Foundation

/// Where they post, how long, how funny (08 §1 `reach`); filled when all three are answered.
nonisolated struct VoiceReach: Codable, Hashable, Sendable {
    var platforms: [Platform]
    var length: VideoLength?
    var humor: HumorLevel?

    init(platforms: [Platform] = [], length: VideoLength? = nil, humor: HumorLevel? = nil) {
        self.platforms = platforms
        self.length = length
        self.humor = humor
    }

    var isComplete: Bool { !platforms.isEmpty && length != nil && humor != nil }
    var isEmpty: Bool { platforms.isEmpty && length == nil && humor == nil }

    private enum CodingKeys: String, CodingKey { case platforms, length, humor }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platforms = (try? container.decodeIfPresent([Platform].self, forKey: .platforms)) ?? []
        length = (try? container.decodeIfPresent(VideoLength.self, forKey: .length)) ?? nil
        humor = (try? container.decodeIfPresent(HumorLevel.self, forKey: .humor)) ?? nil
    }
}
