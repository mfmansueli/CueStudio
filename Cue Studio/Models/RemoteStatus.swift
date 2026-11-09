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
    /// The recorder can start a take from here (Selfie, the microphone allowed): the remote's Record button. Nil from a build before it.
    var canRecord: Bool?
    /// The number of the take recording now, or of the next one.
    var takeNumber: Int?
    /// Seconds the take has recorded when this was sent, while it records.
    var recordingElapsed: TimeInterval?
    /// The countdown before a take is running.
    var isCountingDown: Bool?

    init(
        scriptTitle: String?, isPlaying: Bool, speed: Double, followsVoice: Bool, progress: Double, isRecording: Bool,
        canRecord: Bool? = nil, takeNumber: Int? = nil, recordingElapsed: TimeInterval? = nil, isCountingDown: Bool? = nil
    ) {
        self.scriptTitle = scriptTitle
        self.isPlaying = isPlaying
        self.speed = speed
        self.followsVoice = followsVoice
        self.progress = progress
        self.isRecording = isRecording
        self.canRecord = canRecord
        self.takeNumber = takeNumber
        self.recordingElapsed = recordingElapsed
        self.isCountingDown = isCountingDown
    }

    /// Nothing open on the teleprompter.
    static let idle = RemoteStatus(
        scriptTitle: nil, isPlaying: false, speed: ReadTime.naturalSpeed,
        followsVoice: false, progress: 0, isRecording: false
    )

    /// "1×": how many times the natural reading pace (`SpeedScale`), as on the prompter.
    var speedLabel: String {
        SpeedScale.label(forSpeed: speed)
    }
}
