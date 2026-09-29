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
    /// The language Clean Up listened in.
    private(set) var cleanUpLanguage: SpeechLanguageRequest?
    /// The lines heard, with their words.
    var captions: [CaptionCue] = [CaptionCue(words: [
        CaptionWord(text: "Okay,", start: 0, end: 0.3),
        CaptionWord(text: "real", start: 0.35, end: 0.6),
        CaptionWord(text: "talk.", start: 0.65, end: 1),
    ])]
    /// How listening ends; nil gives `captions`.
    var captionOutcome: CaptionOutcome?
    /// Where listening goes, reported in order before it ends.
    var captionProgress: [CaptionProgress] = [.preparing, .transcribing(0.5)]
    /// How long listening takes, so a test can stop it halfway.
    var captionDelay: Duration?
    /// Listening fails (the sound can't be read).
    var captionFails = false
    private(set) var captionScript: String?
    private(set) var captionLanguage: SpeechLanguageRequest?
    private(set) var captionRequests = 0

    /// The script Clean Up read the language from, when it was left to detect it.
    var cleanUpScript: String? {
        if case .detect(let text, _) = cleanUpLanguage { text } else { nil }
    }

    func sourceDuration(ofVideoAt url: URL) async throws -> TimeInterval {
        guard let duration else { throw EditSourceError.missing }
        return duration
    }

    func frameRate(ofVideoAt url: URL) async -> Double? {
        nominalFrameRate
    }

    func cleanUpSuggestions(forVideoAt url: URL, language: SpeechLanguageRequest) async throws -> [CleanUpSuggestion] {
        guard !cleanUpFails else { throw EditSourceError.noDuration }
        cleanUpLanguage = language
        return CleanUpAnalyzer.suggestions(silences: silences, transcript: transcript)
    }

    func captions(
        forVideoAt url: URL, script: String, language: SpeechLanguageRequest,
        progress: @escaping @Sendable (CaptionProgress) -> Void
    ) async throws -> CaptionOutcome {
        captionScript = script
        captionLanguage = language
        captionRequests += 1
        for step in captionProgress { progress(step) }
        if let captionDelay { try await Task.sleep(for: captionDelay) }
        if captionFails { throw EditSourceError.noDuration }
        return captionOutcome ?? .captions(captions, transcript: CaptionTranscript(words: captions.flatMap(\.words), languageCode: "en"))
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem {
        AVPlayerItem(url: url)
    }

    /// What `coverImage` hands back; nil when the picture can't be read.
    var coverData: Data? = Data([0xFF, 0xD8, 0xFF])
    private(set) var drawnCovers: [VideoCover] = []

    func coverImage(_ cover: VideoCover, forVideoAt url: URL, edit: TakeEdit) async -> Data? {
        drawnCovers.append(cover)
        return coverData
    }
}
