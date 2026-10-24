//
//  QuickEditDraftStoreTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("QuickEditDraftStore")
struct QuickEditDraftStoreTests {
    /// Inside a folder named like the real one: paths with spaces must work.
    private func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: "cue drafts \(UUID().uuidString)/Application Support", directoryHint: .isDirectory)
    }

    private func draft(takeID: UUID = UUID()) -> QuickEditDraft {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        var history = EditHistory<EditSnapshot>()
        history.record(EditSnapshot(timeline: edit.timeline, suggestions: edit.suggestions))
        edit.timeline.trimStart(to: 3)
        return QuickEditDraft(takeID: takeID, edit: edit, playhead: 4.2, history: history, savedAt: TestData.now)
    }

    @Test func aDraftComesBackAsItWasSaved() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let saved = draft()
        try QuickEditDraftStore(directory: directory).save(saved)
        let loaded = QuickEditDraftStore(directory: directory).draft(for: saved.takeID)
        #expect(loaded == saved)
    }

    /// A draft that can't be written says so (Quick edit then never says "Draft saved"): here a file stands where its
    /// folder goes.
    @Test func aDraftThatCantBeWrittenThrows() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: directory.deletingLastPathComponent().appending(path: directory.lastPathComponent, directoryHint: .notDirectory))
        let saved = draft()
        #expect(throws: (any Error).self) { try QuickEditDraftStore(directory: directory).save(saved) }
        #expect(QuickEditDraftStore(directory: directory).draft(for: saved.takeID) == nil)
    }

    @Test func discardingRemovesIt() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = QuickEditDraftStore(directory: directory)
        let saved = draft()
        try store.save(saved)
        store.discard(takeID: saved.takeID)
        #expect(store.draft(for: saved.takeID) == nil)
        store.discard(takeID: UUID())
    }

    @Test func aDraftSavedSoonIsThereForTheNextRead() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = QuickEditDraftStore(directory: directory)
        var older = draft()
        older.playhead = 1
        var newer = older
        newer.playhead = 2
        store.saveSoon(older)
        store.saveSoon(newer)
        #expect(store.draft(for: older.takeID)?.playhead == 2)
    }

    @Test func aDiscardAfterASaveSoonWins() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = QuickEditDraftStore(directory: directory)
        let saved = draft()
        store.saveSoon(saved)
        store.discard(takeID: saved.takeID)
        #expect(store.draft(for: saved.takeID) == nil)
        #expect(!store.hasDraft(for: saved.takeID))
    }

    /// Sixty undo steps of a long take with the same lines: written once, not sixty times, and undoing through the draft read
    /// back gives every step's lines as they were.
    @Test func undoStepsAreWrittenThinAndUndoTheSame() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        var edit = TakeEdit(sourceDuration: 600, aspect: .portrait)
        edit.captions = (0..<400).map { CaptionCue(text: "Line \($0) of a long take", start: Double($0), end: Double($0) + 0.9) }
        var history = EditHistory<EditSnapshot>()
        var wanted: [[CaptionCue]] = []
        for step in 0..<60 {
            history.record(EditSnapshot(edit))
            wanted.append(edit.captions)
            edit.exposure = Double(step)
            // Every tenth step changes a line, so some steps differ from the one after them.
            if step % 10 == 9 { edit.captions[step].text = "Fixed \(step)" }
        }
        let saved = QuickEditDraft(takeID: UUID(), edit: edit, playhead: 0, history: history, savedAt: TestData.now)
        let store = QuickEditDraftStore(directory: directory)
        try store.save(saved)
        let file = directory.appending(path: "\(saved.takeID.uuidString).json")
        let size = try Data(contentsOf: file).count
        let full = try JSONEncoder().encode(saved).count
        #expect(size * 5 < full, "\(size) bytes written, \(full) without thinning")
        var loaded = try #require(store.draft(for: saved.takeID))
        var current = loaded.edit
        for lines in wanted.reversed() {
            let undone = loaded.history.undo(from: EditSnapshot(current))
            let step = try #require(undone)
            current.apply(step)
            #expect(current.captions == lines)
        }
    }

    /// A long take proofread line by line: every undo step changes one line (one adds a line, one deletes one), and each is
    /// written as the lines it changes (with the order when lines came or went), not as all of them; undoing reads them back.
    @Test func lineByLineCorrectionsAreWrittenAsTheLinesTheyChange() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        var edit = TakeEdit(sourceDuration: 1800, aspect: .portrait)
        edit.captions = (0..<600).map { index in
            CaptionCue(text: "Line \(index) of a thirty-minute take", start: Double(index) * 3, end: Double(index) * 3 + 2.6)
        }
        var history = EditHistory<EditSnapshot>()
        var wanted: [[CaptionCue]] = []
        for step in 0..<20 {
            history.record(EditSnapshot(edit))
            wanted.append(edit.captions)
            switch step {
            case 7: edit.captions.insert(CaptionCue(text: "A new line", start: 1000.1, end: 1000.9, origin: .manual), at: 334)
            case 13: edit.captions.remove(at: 40)
            default: edit.captions[step * 25].text = "Corrected line \(step)"
            }
        }
        let saved = QuickEditDraft(takeID: UUID(), edit: edit, playhead: 0, history: history, savedAt: TestData.now)
        let store = QuickEditDraftStore(directory: directory)
        try store.save(saved)
        let size = try Data(contentsOf: directory.appending(path: "\(saved.takeID.uuidString).json")).count
        let alone = QuickEditDraft(takeID: saved.takeID, edit: edit, playhead: 0, history: EditHistory(), savedAt: TestData.now)
        let current = try JSONEncoder().encode(alone).count
        let line = "DRAFT 600 lines, 20 line steps · \(size / 1024) KB written · the edit alone \(current / 1024) KB"
        Attachment.record(line, named: "draft.txt")
        // The steps add little to the edit itself.
        #expect(size < current * 2, "\(size) bytes written, \(current) for the edit alone")
        var loaded = try #require(store.draft(for: saved.takeID))
        var now = loaded.edit
        for lines in wanted.reversed() {
            let undone = loaded.history.undo(from: EditSnapshot(now))
            let step = try #require(undone)
            now.apply(step)
            #expect(now.captions == lines)
        }
    }

    @Test func anUnreadableDraftCountsAsNone() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let takeID = UUID()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appending(path: "\(takeID.uuidString).json"))
        #expect(QuickEditDraftStore(directory: directory).draft(for: takeID) == nil)
    }
}
