//
//  MusicClip.swift
//  Cue Studio
//

import Foundation

/// A sound file of the creator's own (music, an effect) laid under the video. It belongs to the
/// project, not to what is said: it's placed on the edit's own seconds and stays there when
/// something is cut before it. Its file is copied into the edit's media.
nonisolated struct MusicClip: Codable, Hashable, Identifiable, Sendable {
    static let volumeRange: ClosedRange<Double> = 0...2
    static let fadeRange: ClosedRange<Double> = 0...5
    /// Shortest it can play.
    static let minimumDuration: TimeInterval = 0.5
    /// How far it goes down while someone speaks, as a factor (about −12 dB).
    static let duckedLevel: Double = 0.25
    /// How long it takes to go down, and to come back.
    static let duckRamp: TimeInterval = 0.25

    var id = UUID()
    /// The copy's name in `EditMediaFiles`.
    var fileName: String
    var title: String
    /// The file's length.
    var fileDuration: TimeInterval
    /// Edited seconds where it starts.
    var start: TimeInterval
    /// Seconds into the file it starts from.
    var offset: TimeInterval = 0
    /// How long it plays.
    var length: TimeInterval
    var volume: Double = 0.5
    var fadeIn: TimeInterval = 1
    var fadeOut: TimeInterval = 1.5
    var isMuted = false
    /// Goes down while the voice or a voice-over speaks.
    var ducksUnderVoice = true

    init(fileName: String, title: String, fileDuration: TimeInterval, start: TimeInterval, length: TimeInterval) {
        self.fileName = fileName
        self.title = title
        self.fileDuration = max(0, fileDuration)
        self.start = max(0, start)
        self.length = max(0, min(length, fileDuration))
    }

    /// Where it plays in an edit `duration` long; nil when none of it does.
    func span(inEditOf duration: TimeInterval) -> TimeSpan? {
        let end = min(start + length, duration)
        guard end - start >= 0.05 else { return nil }
        return TimeSpan(start: start, end: end)
    }
}
