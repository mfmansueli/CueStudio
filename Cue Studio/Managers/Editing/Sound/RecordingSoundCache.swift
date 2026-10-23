//
//  RecordingSoundCache.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// The sound files Quick edit makes from recordings, made once and shared by the preview, the export, Clean Up and captions:
/// a recording's sound on its own (`audio(of:)`), treated by Studio Voice (`treated`), brought to another level (`leveled`),
/// how loud its speech is (`speechLevel`) and where someone speaks in it (`speechSpans`). A file asked for while it's being made waits for the same work.
///
/// Infrastructure shared by two services (`TakeEditService`, `VideoExportService`), so a singleton (`ARCHITECTURE.md` §2.2).
/// Treated and leveled files are the length of a take (uncompressed: about 23 MB a minute, 1.4 GB for an hour): only the
/// `fileLimit` used most recently are kept, and only as many as fit in `byteBudget`, the others deleted (never one another key
/// still points at: a level that changed nothing is its input file, nor one used in the last `inUse` seconds).
/// Everything is in the temporary folder, made on the device.
actor RecordingSoundCache {
    static let shared = RecordingSoundCache()

    /// Treated and leveled files kept at once: room for a montage of eight recordings, each treated and leveled, so one
    /// preparation never deletes what it just made.
    static let fileLimit = 16

    private enum Key: Hashable {
        case audio(URL)
        case treated(URL, VoiceProcessing)
        case leveled(URL, Int)

        /// A recording's sound as it is, kept apart from the limits (it is made once and is short-lived only with the take).
        var isRecordingSound: Bool {
            if case .audio = self { true } else { false }
        }
    }

    private var files: [Key: URL] = [:]
    /// Treated and leveled files, oldest first.
    private var order: [Key] = []
    private var running: [Key: Task<URL?, Error>] = [:]
    /// When each treated or leveled file was last asked for: one used in the last `inUse` seconds is never deleted (a montage
    /// of many recordings may need more than `fileLimit` at once, and a player may still be reading the previous ones).
    private var lastUsed: [Key: Date] = [:]
    static let inUse: TimeInterval = 120
    private var levels: [URL: Float?] = [:]
    /// The size of each treated or leveled file.
    private var sizes: [Key: Int64] = [:]
    /// Bytes the treated and leveled files may take together; nil: `byteBudget(freeSpace:)` of the space free now.
    private let fixedBudget: Int64?
    /// How long a file just used stays, whatever the limits (`inUse`; tests make it 0).
    private let keepsInUse: TimeInterval
    /// Preparations running now (`RecordingSounds.prepare`), the files they handed out so far, and those the last one finished
    /// handed out: kept whatever the limits, so a long montage's first treatment isn't deleted before its last one is made, nor a
    /// file the preview plays now.
    private var preparations = 0
    private var handingOut: Set<Key> = []
    private var handedOut: Set<Key> = []

    init(byteBudget: Int64? = nil, keepsInUse: TimeInterval = RecordingSoundCache.inUse) {
        fixedBudget = byteBudget
        self.keepsInUse = keepsInUse
    }

    /// A preparation of an edit's sounds begins: what it is handed is kept until the next one finishes.
    func beginPreparation() {
        preparations += 1
    }

    func endPreparation() {
        preparations = max(0, preparations - 1)
        guard preparations == 0 else { return }
        handedOut = handingOut
        handingOut = []
    }

    /// A quarter of the space free on the iPhone, between 512 MB and 3 GB: a few treatments of an hour-long take, never the
    /// room the creator needs to record.
    static func byteBudget(freeSpace: Int64) -> Int64 {
        min(3_000_000_000, max(512_000_000, freeSpace / 4))
    }
    private var speech: [URL: [TimeSpan]] = [:]

    /// Where someone speaks in the recording (for music that ducks), found once per file; none without a sound.
    func speechSpans(in video: URL) async -> [TimeSpan] {
        if let found = speech[video] { return found }
        guard let audio = try? await audio(of: video) else { return [] }
        let found = await Task.detached { (try? VoiceActivity.spans(inAudio: audio)) ?? [] }.value
        speech[video] = found
        return found
    }

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
        if let known = files[key], FileManager.default.fileExists(atPath: known.path(percentEncoded: false)) {
            touch(key)
            return known
        }
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
        touch(key)
        if !key.isRecordingSound {
            sizes[key] = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        }
        let budget = fixedBudget ?? Self.byteBudget(freeSpace: Self.freeSpace())
        let now = Date()
        while order.count > Self.fileLimit || sizes.values.reduce(0, +) > budget {
            // The least recently used that nothing used just now; none such: the cache grows for a while.
            guard let index = order.firstIndex(where: { key in
                now.timeIntervalSince(lastUsed[key] ?? .distantPast) > keepsInUse && !handingOut.contains(key) && !handedOut.contains(key)
            }) else { break }
            let oldest = order.remove(at: index)
            lastUsed[oldest] = nil
            sizes[oldest] = nil
            // A file another key still names (a level that changed nothing returns its input) stays.
            guard let stale = files.removeValue(forKey: oldest), !files.values.contains(stale) else { continue }
            levels[stale] = nil
            try? FileManager.default.removeItem(at: stale)
        }
    }

    /// Space free on the iPhone for files the app makes.
    private static func freeSpace() -> Int64 {
        (try? URL.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
    }

    /// `key` was just used: the last to go.
    private func touch(_ key: Key) {
        if case .audio = key { return }
        if preparations > 0 { handingOut.insert(key) }
        order.removeAll { $0 == key }
        order.append(key)
        lastUsed[key] = Date()
    }
}
