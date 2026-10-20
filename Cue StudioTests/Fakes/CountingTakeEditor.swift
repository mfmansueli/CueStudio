//
//  CountingTakeEditor.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
@testable import Cue_Studio

/// The real media work, counting how many preview items are built: rapid changes must not pile
/// up builds.
@MainActor
final class CountingTakeEditor: TakeEditing {
    private let editing: TakeEditing
    private(set) var previewItems = 0
    /// Whether each build asked for curved clips' sound rendered along the curve.
    private(set) var rendersCurveSound: [Bool] = []

    init(wrapping editing: TakeEditing) {
        self.editing = editing
    }

    func sourceDuration(ofVideoAt url: URL) async throws -> TimeInterval {
        try await editing.sourceDuration(ofVideoAt: url)
    }

    func frameRate(ofVideoAt url: URL) async -> Double? {
        await editing.frameRate(ofVideoAt: url)
    }

    func cleanUpSuggestions(forVideoAt url: URL, language: SpeechLanguageRequest) async throws -> [CleanUpSuggestion] {
        try await editing.cleanUpSuggestions(forVideoAt: url, language: language)
    }

    func captions(
        forVideoAt url: URL, script: String, language: SpeechLanguageRequest, spokenAmong candidates: [CueLanguage],
        progress: @escaping @Sendable (CaptionProgress) -> Void
    ) async throws -> CaptionOutcome {
        try await editing.captions(forVideoAt: url, script: script, language: language, spokenAmong: candidates, progress: progress)
    }

    func previewItem(forVideoAt url: URL, edit: TakeEdit, window: TimeSpan?, rendersCurveSound: Bool) async throws -> AVPlayerItem {
        previewItems += 1
        self.rendersCurveSound.append(rendersCurveSound)
        return try await editing.previewItem(forVideoAt: url, edit: edit, window: window, rendersCurveSound: rendersCurveSound)
    }

    func matchedOriginalVolume(forVideoAt url: URL, edit: TakeEdit) async -> Double? {
        await editing.matchedOriginalVolume(forVideoAt: url, edit: edit)
    }

    func autoCorrection(forVideoAt url: URL, spans: [TimeSpan]) async throws -> AutoCorrection? {
        try await editing.autoCorrection(forVideoAt: url, spans: spans)
    }

    func coverImage(_ cover: VideoCover, forVideoAt url: URL, edit: TakeEdit) async -> Data? {
        await editing.coverImage(cover, forVideoAt: url, edit: edit)
    }

    func stillClip(ofVideoAt url: URL, at time: TimeInterval, length: TimeInterval) async throws -> String {
        try await editing.stillClip(ofVideoAt: url, at: time, length: length)
    }

    func extractSound(_ request: SoundExtraction) async throws -> ExtractedSound {
        try await editing.extractSound(request)
    }
}
