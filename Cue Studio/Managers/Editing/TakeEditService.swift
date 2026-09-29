//
//  TakeEditService.swift
//  Cue Studio
//

import AVFoundation
import UIKit
import Foundation

/// Quick edit's media work with AVFoundation, Core Image and Speech, all on the device. The
/// original recording is only read, never changed.
@MainActor
@Observable
final class TakeEditService: TakeEditing {
    /// Processed sounds kept at once; each is a file the length of a take.
    private static let processedAudioLimit = 4

    /// Audio-only copies of takes, made once per session for analysis and processing.
    private var extractedAudio: [URL: URL] = [:]
    /// The Audio tool's result per recording and setting, so trims and cuts reuse it instead of
    /// processing the whole take again.
    private var processedAudio: [AudioRecipe: URL] = [:]
    private var processedOrder: [AudioRecipe] = []
    /// What was heard in a take, for captions and Clean Up, so it is transcribed once.
    private var transcripts: [TranscriptKey: TakeTranscript] = [:]

    func sourceDuration(ofVideoAt url: URL) async throws -> TimeInterval {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { throw EditSourceError.missing }
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty else { throw EditSourceError.noVideo }
        let seconds = try await asset.load(.duration).seconds
        guard seconds.isFinite, seconds > 0 else { throw EditSourceError.noDuration }
        return seconds
    }

    func frameRate(ofVideoAt url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let rate = try? await track.load(.nominalFrameRate), rate > 0 else { return nil }
        return Double(rate)
    }

    func cleanUpSuggestions(forVideoAt url: URL, language: SpeechLanguageRequest) async throws -> [CleanUpSuggestion] {
        let audio: URL
        do {
            audio = try await audioFile(for: url)
        } catch AudioTrackExtractor.ExtractError.noAudio {
            // Without sound there is nothing to find; that isn't a failure.
            return []
        }
        let levels = try await Task.detached { try AudioLevelReader.levels(of: audio, interval: 0.05) }.value
        let silences = SilenceDetector.silences(levels: levels, interval: 0.05)
        // Without a speech model Clean Up still offers the pauses.
        let heard = try? await transcript(of: audio, language: language)
        return CleanUpAnalyzer.suggestions(silences: silences, transcript: heard)
    }

    func captions(
        forVideoAt url: URL, script: String, language: SpeechLanguageRequest,
        progress: @escaping @Sendable (CaptionProgress) -> Void
    ) async throws -> CaptionOutcome {
        progress(.preparing)
        let audio: URL
        do {
            audio = try await audioFile(for: url)
        } catch AudioTrackExtractor.ExtractError.noAudio {
            return .noAudio
        }
        let heard: TakeTranscript
        do {
            heard = try await transcript(of: audio, language: language, script: script, progress: progress)
        } catch let reason as SpeechUnavailableReason {
            return .unavailable(reason)
        }
        let words = heard.words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end, isEstimated: $0.isEstimated) }
        guard !words.isEmpty else { return .noSpeech }
        let cues = await Task.detached { CaptionBuilder.captions(heard: words, script: script) }.value
        try Task.checkCancellation()
        return .captions(cues, transcript: CaptionTranscript(words: words, languageCode: heard.languageCode))
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem {
        let processed = try await processedAudio(for: url, edit: edit)
        let composition = try await EditedComposition.build(
            source: url, edit: edit, processedAudio: processed,
            options: .init(burnsInCaptions: true, shortSide: 1080)
        )
        let item = AVPlayerItem(asset: composition.asset)
        item.videoComposition = composition.videoComposition
        item.audioMix = composition.audioMix
        // Sped-up or slowed-down pieces keep the voice's pitch.
        item.audioTimePitchAlgorithm = .spectral
        return item
    }

    func coverImage(_ cover: VideoCover, forVideoAt url: URL, edit: TakeEdit) async -> Data? {
        let image = await CoverRenderer.image(for: cover, videoURL: url, edit: edit)
        return image?.jpegData(compressionQuality: 0.92)
    }

    /// The Audio tool's changes rendered to a file, or nil when the sound is untouched or the take
    /// has none.
    func processedAudio(for url: URL, edit: TakeEdit) async throws -> URL? {
        guard edit.volume != 1 || edit.enhancesVoice || edit.reducesNoise else { return nil }
        let recipe = AudioRecipe(url: url, volume: edit.volume, enhancesVoice: edit.enhancesVoice, reducesNoise: edit.reducesNoise)
        if let cached = processedAudio[recipe], FileManager.default.fileExists(atPath: cached.path(percentEncoded: false)) {
            return cached
        }
        let audio: URL
        do {
            audio = try await audioFile(for: url)
        } catch AudioTrackExtractor.ExtractError.noAudio {
            return nil
        }
        let processed = try await Task.detached {
            try AudioEnhancer.process(audio, volume: recipe.volume, enhancesVoice: recipe.enhancesVoice, reducesNoise: recipe.reducesNoise)
        }.value
        remember(processed, for: recipe)
        return processed
    }

    // MARK: - Files

    private func audioFile(for url: URL) async throws -> URL {
        if let cached = extractedAudio[url], FileManager.default.fileExists(atPath: cached.path(percentEncoded: false)) { return cached }
        let audio = try await AudioTrackExtractor.extract(from: url)
        extractedAudio[url] = audio
        return audio
    }

    /// - Parameter script: what was read, so the words come back in the same letters (Hindi).
    /// Throws `SpeechUnavailableReason` when no model can listen in the language.
    private func transcript(
        of audio: URL, language: SpeechLanguageRequest, script: String = "",
        progress: (@Sendable (CaptionProgress) -> Void)? = nil
    ) async throws -> TakeTranscript {
        let key = TranscriptKey(audio: audio, language: language, script: script)
        if let cached = transcripts[key] { return cached }
        let heard = try await CaptionTranscriber.transcript(in: audio, language: language, script: script, progress: progress)
        transcripts[key] = heard
        return heard
    }

    private func remember(_ file: URL, for recipe: AudioRecipe) {
        processedAudio[recipe] = file
        processedOrder.removeAll { $0 == recipe }
        processedOrder.append(recipe)
        while processedOrder.count > Self.processedAudioLimit {
            let oldest = processedOrder.removeFirst()
            if let stale = processedAudio.removeValue(forKey: oldest) {
                try? FileManager.default.removeItem(at: stale)
            }
        }
    }

    /// The language the take is heard in (the Voice Following language, or the script's).
    private struct TranscriptKey: Hashable {
        let audio: URL
        let language: SpeechLanguageRequest
        let script: String
    }

    private struct AudioRecipe: Hashable {
        let url: URL
        let volume: Double
        let enhancesVoice: Bool
        let reducesNoise: Bool
    }
}
