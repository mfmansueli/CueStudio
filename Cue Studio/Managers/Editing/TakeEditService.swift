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
    /// Audio-only copies, Studio Voice's treatments and levels: shared with the export, so trims and cuts (and the export
    /// after them) reuse them instead of treating the whole take again.
    private let sounds: RecordingSoundCache
    /// Which language a take without a script is spoken in.
    private let spokenLanguages: SpokenLanguageIdentifier

    init(sounds: RecordingSoundCache = .shared, spokenLanguages: SpokenLanguageIdentifier = SpokenLanguageIdentifier()) {
        self.sounds = sounds
        self.spokenLanguages = spokenLanguages
    }
    /// What was heard in a take, for captions and Clean Up, so it is transcribed once.
    private var transcripts: [TranscriptKey: TakeTranscript] = [:]
    /// Where someone speaks in each recording, for music that ducks.
    private var speech: [URL: [TimeSpan]] = [:]
    /// The language each recording was found to be spoken in, among the candidates asked (nil: couldn't tell).
    private var spoken: [SpokenKey: CueLanguage?] = [:]

    private struct SpokenKey: Hashable {
        let audio: URL
        let candidates: [CueLanguage]
    }
    /// What Auto measured, per recording and stretch, so measuring the same clip twice is free.
    private var autoCorrections: [AutoKey: AutoCorrection] = [:]
    private var autoOrder: [AutoKey] = []
    private static let autoCorrectionLimit = 24

    private struct AutoKey: Hashable {
        let url: URL
        let spans: [TimeSpan]
    }

    func autoCorrection(forVideoAt url: URL, spans: [TimeSpan]) async throws -> AutoCorrection? {
        let key = AutoKey(url: url, spans: spans)
        if let cached = autoCorrections[key] { return cached }
        guard let measured = try await AutoAdjustAnalyzer.correction(forVideoAt: url, spans: spans) else { return nil }
        autoCorrections[key] = measured
        autoOrder.removeAll { $0 == key }
        autoOrder.append(key)
        while autoOrder.count > Self.autoCorrectionLimit { autoCorrections[autoOrder.removeFirst()] = nil }
        return measured
    }

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
        forVideoAt url: URL, script: String, language: SpeechLanguageRequest, spokenAmong candidates: [CueLanguage],
        progress: @escaping @Sendable (CaptionProgress) -> Void
    ) async throws -> CaptionOutcome {
        progress(.preparing)
        let audio: URL
        do {
            audio = try await audioFile(for: url)
        } catch AudioTrackExtractor.ExtractError.noAudio {
            return .noAudio
        }
        var request = language
        if candidates.count > 1 {
            progress(.findingLanguage)
            if let spoken = try await spokenLanguage(in: audio, among: candidates) { request = .language(spoken) }
        }
        let heard: TakeTranscript
        do {
            heard = try await transcript(of: audio, language: request, script: script, progress: progress)
        } catch let reason as SpeechUnavailableReason {
            return .unavailable(reason)
        }
        let words = heard.words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end, isEstimated: $0.isEstimated) }
        guard !words.isEmpty else { return .noSpeech }
        let language = CueLanguage.matching(languageCode: heard.languageCode)
        let cues = await Task.detached { CaptionBuilder.captions(heard: words, script: script, language: language) }.value
        try Task.checkCancellation()
        return .captions(
            cues,
            transcript: CaptionTranscript(
                words: words, languageCode: heard.languageCode, unheardLanguages: heard.unheardLanguages.isEmpty ? nil : heard.unheardLanguages
            )
        )
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit, window: TimeSpan?, rendersCurveSound: Bool) async throws -> AVPlayerItem {
        let treated = try await RecordingSounds.prepare(for: edit, takeURL: url, cache: sounds)
        let composition = try await EditedComposition.build(
            source: url, edit: edit, sound: treated, speech: await voiceActivity(for: url, edit: edit),
            options: .init(
                burnsInCaptions: true, shortSide: 1080, window: window, analyzesMissingMotion: false,
                rendersCurveSound: rendersCurveSound
            )
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

    func stillClip(ofVideoAt url: URL, at time: TimeInterval, length: TimeInterval) async throws -> String {
        try await StillClipWriter.write(frameOf: url, at: time, length: length)
    }

    func extractSound(_ request: SoundExtraction) async throws -> ExtractedSound {
        var file = request.videoURL
        // What the clip sounds like in the edit: Studio Voice's treatment (and the leveling between recordings), the same file
        // the preview and the export play.
        if let treatment = request.treatment {
            let treated = try await RecordingSounds.prepare(for: treatment.edit, takeURL: treatment.takeURL, cache: sounds)
            if let sound = treated.file(for: treatment.recording) { file = sound }
        }
        return try await SoundExtractor.write(
            from: file, span: request.span, speed: request.speed, keepsPitch: request.keepsPitch, curve: request.curve
        )
    }

    func matchedOriginalVolume(forVideoAt url: URL, edit: TakeEdit) async -> Double? {
        guard let treated = try? await processedAudio(for: url, edit: edit),
              let untreated = try? await audioFile(for: url) else { return nil }
        let levels = await Task.detached {
            (try? SpeechLoudness.level(ofAudio: treated), try? SpeechLoudness.level(ofAudio: untreated))
        }.value
        guard let target = levels.0 ?? nil, let level = levels.1 ?? nil else { return nil }
        return min(SpeechLoudness.volume(matching: level, to: target), 4)
    }

    /// The Voice tool's changes to the take's sound rendered to a file, or nil when the sound is untouched or the take
    /// has none.
    func processedAudio(for url: URL, edit: TakeEdit) async throws -> URL? {
        let processing = edit.voiceProcessing
        guard processing.isNeeded else { return nil }
        return try await sounds.treated(url, processing: processing)
    }

    /// Where someone speaks in the take and the other recordings the edit plays; nothing when no
    /// music ducks.
    private func voiceActivity(for url: URL, edit: TakeEdit) async -> VoiceActivity {
        guard edit.ducksMusic else { return .none }
        var activity = VoiceActivity()
        activity.take = await speechSpans(in: url)
        for source in edit.playedSources {
            activity.sources[source.id] = await speechSpans(in: EditMediaFiles.url(for: source.fileName))
        }
        return activity
    }

    private func speechSpans(in video: URL) async -> [TimeSpan] {
        if let cached = speech[video] { return cached }
        guard let audio = try? await audioFile(for: video) else { return [] }
        let spans = await Task.detached { (try? VoiceActivity.spans(inAudio: audio)) ?? [] }.value
        speech[video] = spans
        return spans
    }

    /// The language the take is spoken in among `candidates`, found once per recording and list.
    private func spokenLanguage(in audio: URL, among candidates: [CueLanguage]) async throws -> CueLanguage? {
        let key = SpokenKey(audio: audio, candidates: candidates)
        if let found = spoken[key] { return found }
        let found = try await spokenLanguages.spokenLanguage(in: audio, among: candidates)
        spoken[key] = found
        return found
    }

    // MARK: - Files

    /// The recording's sound on its own; throws `AudioTrackExtractor.ExtractError.noAudio` when it has none.
    private func audioFile(for url: URL) async throws -> URL {
        guard let audio = try await sounds.audio(of: url) else { throw AudioTrackExtractor.ExtractError.noAudio }
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

    /// The language the take is heard in (the Voice Following language, or the script's).
    private struct TranscriptKey: Hashable {
        let audio: URL
        let language: SpeechLanguageRequest
        let script: String
    }
}
