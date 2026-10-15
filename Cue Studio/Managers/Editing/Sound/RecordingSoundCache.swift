//
//  RecordingSoundCache.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// The sound files Quick edit makes from recordings, made once and shared by the preview, the export, Clean Up and captions:
/// a recording's sound on its own (`audio(of:)`), treated by Studio Voice (`treated`), brought to another level (`leveled`),
/// and how loud its speech is (`speechLevel`). A file asked for while it's being made waits for the same work.
///
/// Infrastructure shared by two services (`TakeEditService`, `VideoExportService`), so a singleton (`ARCHITECTURE.md` §2.2).
/// Treated and leveled files are the length of a take: only the most recent `fileLimit` are kept, the older ones deleted.
/// Everything is in the temporary folder, made on the device.
actor RecordingSoundCache {
    static let shared = RecordingSoundCache()

    /// Treated and leveled files kept at once.
    static let fileLimit = 8

    private enum Key: Hashable {
        case audio(URL)
        case treated(URL, VoiceProcessing)
        case leveled(URL, Int)
    }

    private var files: [Key: URL] = [:]
    /// Treated and leveled files, oldest first.
    private var order: [Key] = []
    private var running: [Key: Task<URL?, Error>] = [:]
    private var levels: [URL: Float?] = [:]

    /// The recording's sound as an audio file; nil when it has none.
    func audio(of video: URL) async throws -> URL? {
        try await file(for: .audio(video)) {
            do {
                return try await AudioTrackExtractor.extract(from: video)
            } catch AudioTrackExtractor.ExtractError.noAudio {
                return nil
            }
        }
    }

    /// The recording's sound treated as `processing` says; nil when it has none.
    func treated(_ video: URL, processing: VoiceProcessing) async throws -> URL? {
        guard let audio = try await audio(of: video) else { return nil }
        return try await file(for: .treated(video, processing)) {
            try await Task.detached { try AudioEnhancer.process(audio, processing: processing) }.value
        }
    }

    /// `file` `decibels` louder (or quieter), never past `AudioCeiling`.
    func leveled(_ file: URL, gain decibels: Float) async throws -> URL {
        // Tenths of a dB: closer readings are the same file.
        let tenths = Int((decibels * 10).rounded())
        let made = try await self.file(for: .leveled(file, tenths)) {
            try await Task.detached { try AudioCeiling.leveled(file, gain: Float(tenths) / 10) }.value
        }
        return made ?? file
    }

    /// How loud the speech in `file` is (dBFS); nil without speech.
    func speechLevel(of file: URL) async throws -> Float? {
        if let known = levels[file] { return known }
        let level = try await Task.detached { try SpeechLoudness.level(ofAudio: file) }.value
        levels[file] = level
        return level
    }

    // MARK: - Private

    private func file(for key: Key, make: @escaping @Sendable () async throws -> URL?) async throws -> URL? {
        if let known = files[key], FileManager.default.fileExists(atPath: known.path(percentEncoded: false)) { return known }
        if let task = running[key] { return try await task.value }
        let task = Task { try await make() }
        running[key] = task
        defer { running[key] = nil }
        let made = try await task.value
        if let made { remember(made, for: key) }
        return made
    }

    private func remember(_ file: URL, for key: Key) {
        files[key] = file
        if case .audio = key { return }
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > Self.fileLimit {
            let oldest = order.removeFirst()
            if let stale = files.removeValue(forKey: oldest) {
                levels[stale] = nil
                try? FileManager.default.removeItem(at: stale)
            }
        }
    }
}
