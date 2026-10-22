//
//  MusicClip.swift
//  Cue Studio
//

import Foundation

/// A sound file of the creator's own (music, an effect) laid under the video. It belongs to the
/// project, not to what is said: it's placed on the edit's own seconds and stays there when
/// something is cut before it. Its file is copied into the edit's media.
nonisolated struct MusicClip: Codable, Hashable, Identifiable, Sendable {
    /// The fades a music starts with.
    static let defaultFadeIn: TimeInterval = 1
    static let defaultFadeOut: TimeInterval = 1.5

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
    var fadeIn: TimeInterval = MusicClip.defaultFadeIn
    var fadeOut: TimeInterval = MusicClip.defaultFadeOut
    var isMuted = false
    /// Goes down while the voice or a voice-over speaks.
    var ducksUnderVoice = true
    /// The sound effect it is (`SoundEffectSynth`); nil for the creator's own file. Effects can play over music and each other.
    var effect: SoundEffect?
    /// The sound of a clip or a video taken out to this track (Extract audio); nil for music and effects.
    var extractedFrom: ExtractedSoundOrigin?

    /// Follows the moment of the video it was put on when the cuts change: effects and extracted sounds. Music keeps its place.
    var followsTheVideo: Bool { effect != nil || extractedFrom != nil }

    /// Music takes the room it plays in (new music goes beside it); effects and extracted sounds play over it.
    var takesMusicRoom: Bool { !followsTheVideo }

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
