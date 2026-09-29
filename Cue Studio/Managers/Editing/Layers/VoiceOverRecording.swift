//
//  VoiceOverRecording.swift
//  Cue Studio
//

import Foundation

/// Records voice-overs for Quick edit. Screens depend on this protocol so tests can use a fake.
protocol VoiceOverRecording: AnyObject {
    var isRecording: Bool { get }
    /// Seconds recorded so far.
    var elapsed: TimeInterval { get }
    /// Asks for the microphone once; false when it's off for Cue.
    func requestPermission() async -> Bool
    /// Starts recording into a new file in `EditMediaFiles`.
    func start() async throws
    /// Stops and hands back the file and its length; nil when nothing was recording.
    func stop() -> (fileName: String, duration: TimeInterval)?
    /// Stops and throws the recording away.
    func cancel()
}
