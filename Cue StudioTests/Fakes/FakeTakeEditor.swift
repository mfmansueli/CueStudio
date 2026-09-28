//
//  FakeTakeEditor.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
@testable import Cue_Studio

@MainActor
final class FakeTakeEditor: TakeEditing {
    /// Nil: the recording is missing.
    var duration: TimeInterval? = 64
    /// Frames per second the file reports; nil when it doesn't say.
    var nominalFrameRate: Double? = 30
    var silences: [TimeSpan] = [TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 31)]
    /// What the transcript heard; nil when no speech model could listen.
    var transcript: TakeTranscript?
    /// The take's sound can't be read.
    var cleanUpFails = false
    private(set) var cleanUpScript: String?
    var captions: [CaptionCue] = [CaptionCue(text: "Okay, real talk.", start: 0, end: 1)]
    private(set) var captionScript: String?

    func sourceDuration(ofVideoAt url: URL) async throws -> TimeInterval {
        guard let duration else { throw EditSourceError.missing }
        return duration
    }

    func frameRate(ofVideoAt url: URL) async -> Double? {
        nominalFrameRate
    }

    func cleanUpSuggestions(forVideoAt url: URL, script: String) async throws -> [CleanUpSuggestion] {
        guard !cleanUpFails else { throw EditSourceError.noDuration }
        cleanUpScript = script
        return CleanUpAnalyzer.suggestions(silences: silences, transcript: transcript)
    }

    func captions(forVideoAt url: URL, script: String, duration: TimeInterval) async -> [CaptionCue] {
        captionScript = script
        return captions
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem {
        AVPlayerItem(url: url)
    }
}
