//
//  TakeLibraryService.swift
//  Cue Studio
//

import Foundation
import os

/// Recorded takes. Each take remembers the script version it was read from.
@MainActor
@Observable
final class TakeLibraryService {
    /// Newest first.
    private(set) var takes: [Take] = []

    private let repository: TakeRepository
    private let now: () -> Date
    private let logger = Logger(subsystem: "studio.cue", category: "TakeLibrary")

    init(repository: TakeRepository = LocalTakeRepository(), now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    func load() {
        do {
            takes = try repository.loadTakes().sorted { $0.recordedAt > $1.recordedAt }
        } catch {
            logger.error("Could not load takes: \(error.localizedDescription)")
        }
    }

    // MARK: - Reading

    func take(id: UUID?) -> Take? {
        guard let id else { return nil }
        return takes.first { $0.id == id }
    }

    /// Newest first.
    func takes(for scriptID: UUID) -> [Take] {
        takes.filter { $0.scriptID == scriptID }
    }

    func count(for scriptID: UUID) -> Int {
        takes.reduce(0) { $0 + ($1.scriptID == scriptID ? 1 : 0) }
    }

    func videoURL(for take: Take) -> URL {
        repository.videoURL(named: take.fileName)
    }

    /// Take numbers keep counting per script (freestyle recordings share one counter).
    func nextNumber(for scriptID: UUID?) -> Int {
        (takes.filter { $0.scriptID == scriptID }.map(\.number).max() ?? 0) + 1
    }

    // MARK: - Actions

    /// Moves the recording into the library and records its metadata.
    @discardableResult
    func addTake(fileAt url: URL, duration: TimeInterval, script: Script?, camera: CameraSettings) throws -> Take {
        let fileName = try repository.storeVideo(from: url)
        let take = Take(
            scriptID: script?.id,
            scriptTitle: script?.displayTitle ?? String(localized: "Freestyle recording"),
            scriptVersion: script?.version,
            number: nextNumber(for: script?.id),
            duration: duration,
            recordedAt: now(),
            fileName: fileName,
            resolution: camera.resolution,
            frameRate: camera.frameRate,
            aspect: camera.aspect,
            platform: script?.platform
        )
        takes.insert(take, at: 0)
        persist()
        return take
    }

    /// One best take per script: marking a take unmarks the others.
    func setBest(_ id: UUID, isBest: Bool) {
        guard let target = take(id: id) else { return }
        for index in takes.indices where takes[index].scriptID == target.scriptID {
            takes[index].isBest = isBest && takes[index].id == id
        }
        persist()
    }

    func delete(_ id: UUID) {
        guard let take = take(id: id) else { return }
        do {
            try repository.deleteVideo(named: take.fileName)
        } catch {
            logger.error("Could not delete take video: \(error.localizedDescription)")
        }
        takes.removeAll { $0.id == id }
        persist()
    }

    /// Keeps take titles in step when a script is renamed.
    func renameScript(_ scriptID: UUID, to title: String) {
        var changed = false
        for index in takes.indices where takes[index].scriptID == scriptID && takes[index].scriptTitle != title {
            takes[index].scriptTitle = title
            changed = true
        }
        if changed { persist() }
    }

    private func persist() {
        do {
            try repository.saveTakes(takes)
        } catch {
            logger.error("Could not save takes: \(error.localizedDescription)")
        }
    }
}
