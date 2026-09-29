//
//  RemoteStatus.swift
//  Cue Studio
//

import Foundation

/// What the teleprompter tells the remote, so its screen shows the real state.
nonisolated struct RemoteStatus: Codable, Hashable, Sendable {
    /// Nil while no script is open in the teleprompter.
    var scriptTitle: String?
    var isPlaying: Bool
    var speed: Double
    /// Voice Following sets the pace; speed doesn't apply.
    var followsVoice: Bool
    /// 0...1
    var progress: Double
    var isRecording: Bool

    /// Nothing open on the teleprompter.
    static let idle = RemoteStatus(
        scriptTitle: nil, isPlaying: false, speed: ReadTime.naturalSpeed,
        followsVoice: false, progress: 0, isRecording: false
    )

    /// "0.7×"
    var speedLabel: String {
        speed.formatted(.number.precision(.fractionLength(1))) + "×"
    }
}
