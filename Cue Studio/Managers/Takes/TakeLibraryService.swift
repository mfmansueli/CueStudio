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

    /// The take and the others of its video (same script), by number, for the review strip. A
    /// freestyle take stands alone.
    func siblings(of take: Take) -> [Take] {
        guard let scriptID = take.scriptID else { return [take] }
        return takes.filter { $0.scriptID == scriptID }.sorted { $0.number < $1.number }
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

    /// Moves the recording into the library and records its metadata. A background effect chosen
    /// while recording becomes the take's recipe (the recording keeps the camera's own image).
    @discardableResult
    func addTake(
        fileAt url: URL, duration: TimeInterval, script: Script?, camera: CameraSettings, background: BackgroundEffect? = nil
    ) throws -> Take {
        let fileName = try repository.storeVideo(from: url)
        var take = Take(
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
        if let background, background.isActive {
            var edit = TakeEdit(sourceDuration: duration, aspect: camera.aspect)
            edit.setBackground(background, for: nil)
            take.edit = edit
        }
        takes.insert(take, at: 0)
        persist()
        return take
    }

    /// One best take per script: marking a take unmarks the others. A freestyle take is a video of
    /// its own, so it never unmarks other freestyle takes.
    func setBest(_ id: UUID, isBest: Bool) {
        guard let target = take(id: id) else { return }
        for index in takes.indices where takes[index].id == id || (target.scriptID != nil && takes[index].scriptID == target.scriptID) {
            takes[index].isBest = isBest && takes[index].id == id
        }
        persist()
    }

    /// Quick edit's Done: keeps the recipe, the new length and the Edited mark. The video file is
    /// untouched.
    func applyEdit(_ edit: TakeEdit, to id: UUID) {
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return }
        takes[index].edit = edit
        takes[index].duration = edit.editedDuration
        takes[index].isEdited = true
        persist()
    }

    /// Saved or shared: it no longer counts as "Not shared".
    func markExported(_ id: UUID) {
        guard let index = takes.firstIndex(where: { $0.id == id }), !takes[index].isExported else { return }
        takes[index].isExported = true
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
        // What Quick edit added belongs to this take alone.
        if let names = take.edit?.mediaFileNames, !names.isEmpty { EditMediaFiles.remove(names) }
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
