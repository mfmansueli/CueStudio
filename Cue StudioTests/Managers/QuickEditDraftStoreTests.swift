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
        var history = EditHistory<EditTimeline>()
        history.record(edit.timeline)
        edit.timeline.trimStart(to: 3)
        return QuickEditDraft(takeID: takeID, edit: edit, playhead: 4.2, history: history, savedAt: TestData.now)
    }

    @Test func aDraftComesBackAsItWasSaved() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let saved = draft()
        QuickEditDraftStore(directory: directory).save(saved)
        let loaded = QuickEditDraftStore(directory: directory).draft(for: saved.takeID)
        #expect(loaded == saved)
    }

    @Test func discardingRemovesIt() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = QuickEditDraftStore(directory: directory)
        let saved = draft()
        store.save(saved)
        store.discard(takeID: saved.takeID)
        #expect(store.draft(for: saved.takeID) == nil)
        store.discard(takeID: UUID())
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
