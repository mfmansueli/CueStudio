//
//  RecordingSounds.swift
//  Cue Studio
//

import Foundation

/// The sound each recording of an edit plays with, when it isn't the file's own: the take's and the montage's other
/// recordings' Studio Voice treatment, evened out in level (`VoiceLeveling`). Made once per recording and setting by
/// `RecordingSoundCache`, so the preview and the export play the same files and the export doesn't treat again what the
/// preview already did.
nonisolated struct RecordingSounds: Hashable, Sendable {
    /// Replaces the take's sound; nil plays it as recorded.
    var take: URL?
    /// Replaces another recording's sound, by `ClipSource.id`.
    var sources: [UUID: URL] = [:]

    static let none = RecordingSounds()

    func file(for sourceID: UUID?) -> URL? {
        sourceID.map { sources[$0] } ?? take
    }

    /// Every file, for keeping their assets while a composition is built.
    var files: [URL] {
        [take].compactMap(\.self) + sources.values
    }

    /// The sounds `edit` plays with: each treated recording's treatment, then, when the edit evens levels out, each brought to
    /// the take's level. `takeURL` is the take's video; the other recordings are read from the edit's media.
    static func prepare(for edit: TakeEdit, takeURL: URL, cache: RecordingSoundCache = .shared) async throws -> RecordingSounds {
        let urls = Dictionary(uniqueKeysWithValues: edit.playedSources.map { ($0.id as UUID?, EditMediaFiles.url(for: $0.fileName)) })
        func video(_ id: UUID?) -> URL? { id == nil ? takeURL : urls[id] }
        let levels = edit.evensOutLevels
        // What each treated recording sounds like before leveling, and whether that's a change from the file.
        var sound: [UUID?: (file: URL, changed: Bool)] = [:]
        for id in edit.treatedRecordingIDs {
            guard let url = video(id) else { continue }
            let processing = edit.voiceProcessing(for: id)
            if processing.isNeeded {
                if let treated = try await cache.treated(url, processing: processing) { sound[id] = (treated, true) }
            } else if levels, let plain = try await cache.audio(of: url) {
                sound[id] = (plain, false)
            }
        }
        if levels {
            var measured: [UUID?: Float] = [:]
            for (id, entry) in sound {
                if let level = try await cache.speechLevel(of: entry.file) { measured[id] = level }
            }
            for (id, gain) in VoiceLeveling.gains(levels: measured) {
                guard let entry = sound[id] else { continue }
                sound[id] = (try await cache.leveled(entry.file, gain: gain), true)
            }
        }
        var result = RecordingSounds()
        for (id, entry) in sound where entry.changed {
            if let id { result.sources[id] = entry.file } else { result.take = entry.file }
        }
        return result
    }
}
