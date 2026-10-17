//
//  FaceFollow.swift
//  Cue Studio
//

import Foundation

/// Format › Follow face: the crop moves with the creator's face over the whole video, at `pace`. Each recording of a montage
/// follows the face found in it (`MotionAnalysis`); until a recording is analyzed, or when no face is found in it, its crop
/// stays where Format puts it.
nonisolated struct FaceFollow: Codable, Hashable, Sendable {
    var pace: FollowPace = .natural

    init(pace: FollowPace = .natural) {
        self.pace = pace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pace = (try? container.decodeIfPresent(FollowPace.self, forKey: .pace)) ?? .natural
    }
}
