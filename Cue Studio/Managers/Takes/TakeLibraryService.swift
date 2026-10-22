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

    /// Told about each take recorded (Cue learns from a draft the creator made their own, `DraftLearningService`).
    @ObservationIgnored var onTakeAdded: ((Take) -> Void)?

    private let repository: TakeRepository
    /// Quick edit's drafts: a deleted take's draft, and what only the draft named, go with it.
    private let drafts: QuickEditDraftStoring?
    private let now: () -> Date
    private let logger = Logger(subsystem: "studio.cue", category: "TakeLibrary")
    /// False when the library on disk couldn't be read: writing would replace it with what's in memory.
    @ObservationIgnored private var canSave = true
    /// The last write failed (the iPhone full): what changed is only in memory until a save works, the next change's or
    /// `saveAgainIfFailed` when Cue comes back to the front. The app says so (`RootView`).
    private(set) var saveFailed = false

    init(repository: TakeRepository = LocalTakeRepository(), drafts: QuickEditDraftStoring? = nil, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.drafts = drafts
        self.now = now
    }

    func load() {
        do {
            takes = try repository.loadTakes().sorted { $0.recordedAt > $1.recordedAt }
            canSave = true
        } catch {
            // The library is there but couldn't be read (say, before the first unlock): saving now would write an empty
            // library over it. Nothing is saved until it is read (`reloadIfUnread`).
            canSave = false
            logger.error("Could not load takes: \(error.localizedDescription)")
        }
    }

    /// The library couldn't be read at launch (Cue woke in the background before the first unlock): read it again now,
    /// keeping the takes recorded since, so nothing made meanwhile is lost and saving can go on.
    func reloadIfUnread() {
        guard !canSave, let saved = try? repository.loadTakes() else { return }
        let made = Set(takes.map(\.id))
        takes = (takes + saved.filter { !made.contains($0.id) }).sorted { $0.recordedAt > $1.recordedAt }
        canSave = true
        logger.notice("Takes read after all: \(saved.count) on disk, \(made.count) made meanwhile")
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
    /// while recording becomes the take's recipe (the recording keeps the camera's own image). When the library can't be
    /// written (the iPhone full), the take isn't added and its video goes back where the camera left it, where
    /// `TakeRecovery` finds it at the next launch: never a video in the library that no take points to.
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
        take.scriptReference = script
        if let background, background.isActive {
            var edit = TakeEdit(sourceDuration: duration, aspect: camera.aspect)
            edit.setBackground(background, for: nil)
            take.edit = edit
        }
        takes.insert(take, at: 0)
        do {
            try save()
        } catch {
            takes.removeAll { $0.id == take.id }
            do {
                try repository.returnVideo(named: fileName, to: url)
            } catch {
                logger.error("Could not put the unsaved take's video back: \(error.localizedDescription)")
            }
            throw error
        }
        onTakeAdded?(take)
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
    /// untouched. Throws when the library couldn't be written: the take keeps the edit in memory (the next save writes
    /// it), but nothing is on disk yet, so Quick edit keeps its draft.
    func applyEdit(_ edit: TakeEdit, to id: UUID) throws {
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return }
        takes[index].edit = edit
        takes[index].duration = edit.editedDuration
        takes[index].isEdited = true
        try save()
    }

    /// Recognition is source data, not a destructive edit. Repeated exports and editor sessions
    /// reuse it without changing the timeline, caption visibility, or the Edited mark.
    func cacheCaptions(_ lines: [CaptionCue], transcript: CaptionTranscript, for id: UUID) {
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return }
        var edit = takes[index].edit ?? TakeEdit(sourceDuration: takes[index].duration, aspect: takes[index].aspect)
        guard edit.captions.isEmpty else { return }
        if takes[index].edit == nil {
            edit.captionCollection?.safeMargins = CaptionSafeArea.margins(for: takes[index], aspect: edit.aspect)
            edit.voiceEnhancement = .off
            edit.enhancesVoice = false
        }
        edit.captions = lines
        edit.captionTranscript = transcript
        takes[index].edit = edit
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
        removeEditFiles(of: take)
    }

    /// A take taken out of the library whose video is still on disk, so "Undo" can bring it back (the review's trash).
    struct RemovedTake: Equatable {
        let take: Take
        let position: Int
    }

    /// Removes a take at once, **keeping its video** until `purge` (Delete with 4 s of Undo).
    func remove(_ id: UUID) -> RemovedTake? {
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = RemovedTake(take: takes[index], position: index)
        takes.remove(at: index)
        persist()
        return removed
    }

    /// Undo: the take is back where it was, with its video.
    func restore(_ removed: RemovedTake) {
        guard !takes.contains(where: { $0.id == removed.take.id }) else { return }
        takes.insert(removed.take, at: min(removed.position, takes.count))
        persist()
    }

    /// The 4 seconds are over: the video and what Quick edit added go for good (unless the take came back).
    func purge(_ removed: RemovedTake) {
        guard !takes.contains(where: { $0.id == removed.take.id }) else { return }
        do {
            try repository.deleteVideo(named: removed.take.fileName)
        } catch {
            logger.error("Could not delete take video: \(error.localizedDescription)")
        }
        removeEditFiles(of: removed.take)
    }

    /// What Quick edit added belongs to this take alone: the saved edit's media, and the draft with the media only it names
    /// (B-roll added since the last Done).
    private func removeEditFiles(of take: Take) {
        var names = take.edit?.mediaFileNames ?? []
        if let drafts {
            names.formUnion(drafts.draft(for: take.id)?.edit.mediaFileNames ?? [])
            drafts.discard(takeID: take.id)
        }
        if !names.isEmpty { EditMediaFiles.remove(names) }
    }

    /// "Delete my Cue data", after each take was deleted: the library's whole folder goes, with whatever no take pointed
    /// to and a library that couldn't be read, and an empty one starts.
    func deleteEverything() {
        repository.deleteEverything()
        takes = []
        canSave = true
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
            try save()
        } catch {
            logger.error("Could not save takes: \(error.localizedDescription)")
        }
    }

    /// Writes the library. One that couldn't be read isn't written over: what changed stays in memory and is saved
    /// with what's on disk once it can be read (`reloadIfUnread`), so that's no failure. Throws when the write fails.
    private func save() throws {
        reloadIfUnread()
        guard canSave else {
            logger.error("Not saving takes: the library on disk still can't be read")
            return
        }
        do {
            try repository.saveTakes(takes)
            if saveFailed { saveFailed = false }
        } catch {
            saveFailed = true
            throw error
        }
    }

    /// Writes what a failed save left only in memory.
    func saveAgainIfFailed() {
        guard saveFailed else { return }
        persist()
    }
}
