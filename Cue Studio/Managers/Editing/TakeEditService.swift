//
//  TakeEditService.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Quick edit's media work with AVFoundation, Core Image and Speech, all on the device. The
/// original recording is only read, never changed.
@MainActor
@Observable
final class TakeEditService: TakeEditing {
    /// Audio-only copies of takes, made once per session for analysis and processing.
    private var extractedAudio: [URL: URL] = [:]

    func silences(inVideoAt url: URL) async throws -> [TimeSpan] {
        let audio = try await audioFile(for: url)
        let levels = try await Task.detached { try AudioLevelReader.levels(of: audio, interval: 0.05) }.value
        return SilenceDetector.silences(levels: levels, interval: 0.05)
    }

    func captions(forVideoAt url: URL, script: String, duration: TimeInterval) async -> [CaptionCue] {
        guard !script.isEmpty else { return [] }
        if let audio = try? await audioFile(for: url),
           let words = try? await CaptionTranscriber.words(in: audio, script: script),
           !words.isEmpty {
            return CaptionBuilder.captions(heard: words, script: script)
        }
        return CaptionBuilder.captions(script: script, duration: duration)
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem {
        let processed = try await processedAudio(for: url, edit: edit)
        let composition = try await EditedComposition.build(
            source: url, edit: edit, processedAudio: processed,
            options: .init(burnsInCaptions: true, watermark: false, shortSide: 1080)
        )
        let item = AVPlayerItem(asset: composition.asset)
        item.videoComposition = composition.videoComposition
        return item
    }

    /// The Audio tool's changes rendered to a file, or nil when the sound is untouched.
    func processedAudio(for url: URL, edit: TakeEdit) async throws -> URL? {
        guard edit.volume != 1 || edit.enhancesVoice || edit.reducesNoise else { return nil }
        let audio = try await audioFile(for: url)
        let volume = edit.volume, enhances = edit.enhancesVoice, reduces = edit.reducesNoise
        return try await Task.detached {
            try AudioEnhancer.process(audio, volume: volume, enhancesVoice: enhances, reducesNoise: reduces)
        }.value
    }

    private func audioFile(for url: URL) async throws -> URL {
        if let cached = extractedAudio[url], FileManager.default.fileExists(atPath: cached.path(percentEncoded: false)) { return cached }
        let audio = try await AudioTrackExtractor.extract(from: url)
        extractedAudio[url] = audio
        return audio
    }
}
