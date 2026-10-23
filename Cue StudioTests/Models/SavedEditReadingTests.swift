//
//  SavedEditReadingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A take saved by an earlier version still opens with its whole edit (`Fixtures/SavedEdits/saved-takes-<version>.json`:
/// one file per released version, frozen, never rewritten), and one saved by a newer version (a filter, font, color or
/// transition this one doesn't know, a sound or a picture kind it can't show) still opens, with stand-ins or without that
/// part, while the store keeps the file as it was.
@MainActor
@Suite("Saved edits keep reading")
struct SavedEditReadingTests {
    private final class BundleToken {}

    /// Writes this version's file, once per released version: `TEST_RUNNER_CUE_SAVED_EDIT_FIXTURE=<path>`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_SAVED_EDIT_FIXTURE"] != nil))
    func writeThisVersionsTakes() throws {
        let url = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_SAVED_EDIT_FIXTURE"]))
        let encoder = JSONEncoder.library
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode([Self.take()]).write(to: url)
    }

    @Test func takesSavedByEveryVersionOpenWhole() throws {
        let urls = Self.savedTakes()
        #expect(!urls.isEmpty)
        for url in urls {
            let report = DecodingReport()
            let takes = try JSONDecoder.library.reporting(to: report).decode([Take].self, from: Data(contentsOf: url))
            #expect(report.notes.isEmpty, "\(url.lastPathComponent): \(report.notes)")
            let edit = try #require(takes.first?.edit, "\(url.lastPathComponent) lost its edit")
            #expect(edit.timeline.segments.count == 2)
            #expect(edit.texts.count == 1)
            #expect(edit.media.count == 1)
            #expect(edit.music.count == 1)
            #expect(edit.voiceOvers.count == 1)
            #expect(edit.captions.count == 1)
            #expect(edit.cover != nil)
        }
    }

    @Test func version1TakesKeepTheirChoices() throws {
        let url = try #require(Self.savedTakes().first { $0.lastPathComponent == "saved-takes-1.0.json" })
        let edit = try #require(try JSONDecoder.library.decode([Take].self, from: Data(contentsOf: url)).first?.edit)
        #expect(edit.filter == .warmFilm)
        #expect(edit.texts.first?.font == .montserrat)
        #expect(edit.texts.first?.color == .peach)
        #expect(edit.timeline.transition(atJoin: 1) == .push)
        #expect(edit.captionCollection?.theme == .pop)
        #expect(edit.aspect == .square)
        #expect(edit.captionLanguage == .spanish)
    }

    @Test func aTakeFromANewerVersionOpensWithStandInsAndTheFileIsKept() throws {
        let directory = try Self.library(with: Self.newer { edit in
            edit["filter"] = "auroraFilm"
            edit["aspect"] = "3:4"
            Self.change(&edit, "texts", 0) { text in
                text["font"] = "futureSans"
                text["color"] = "ultraviolet"
                text["backgroundColor"] = "neonPink"
                text["weight"] = "ultra"
            }
            Self.change(&edit, "music", 0) { $0["effect"] = "laser" }
            Self.change(&edit, "media", 0) { $0["kind"] = "sticker" }
            var timeline = edit["timeline"] as? [String: Any] ?? [:]
            var segments = timeline["segments"] as? [[String: Any]] ?? []
            segments[1]["transitionIn"] = "spin"
            timeline["segments"] = segments
            edit["timeline"] = timeline
            var captions = edit["captionCollection"] as? [String: Any] ?? [:]
            captions["theme"] = "neon"
            edit["captionCollection"] = captions
        })
        defer { try? FileManager.default.removeItem(at: directory) }
        let takes = try LocalTakeRepository(directory: directory).loadTakes()
        let edit = try #require(takes.first?.edit)
        #expect(edit.filter == .original)
        #expect(edit.aspect == .portrait)
        #expect(edit.texts.first?.font == .sfPro)
        #expect(edit.texts.first?.color == .white)
        // Each place's own stand-in: a background reads black (never a white box), a weight the texts' bold.
        #expect(edit.texts.first?.backgroundColor == .black)
        #expect(edit.texts.first?.weight == .bold)
        #expect(edit.texts.first?.text == "Comidas de SP")
        #expect(edit.timeline.transition(atJoin: 1) == .hardCut)
        #expect(edit.captionCollection?.theme == .cue)
        // A sound or a picture kind it can't show is left out, never played or drawn as another.
        #expect(edit.music.isEmpty)
        #expect(edit.media.isEmpty)
        #expect(edit.voiceOvers.count == 1)
        #expect(Self.keptCopies(in: directory) == 1)
    }

    @Test func anEditThatCantBeReadNeverHidesTheTake() throws {
        let directory = try Self.library(with: Self.newer { edit in edit["timeline"] = "a timeline from the future" })
        defer { try? FileManager.default.removeItem(at: directory) }
        let takes = try LocalTakeRepository(directory: directory).loadTakes()
        #expect(takes.count == 1)
        #expect(takes.first?.edit == nil)
        #expect(Self.keptCopies(in: directory) == 1)
    }

    @Test func aTakeReadWholeKeepsNoCopy() throws {
        let directory = try Self.library(with: Self.newer { _ in })
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(try LocalTakeRepository(directory: directory).loadTakes().first?.edit != nil)
        #expect(Self.keptCopies(in: directory) == 0)
    }

    @Test func aDraftWhoseUndoStepsCantBeReadStillOpens() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QuickEditDraftStore(directory: directory)
        var history = EditHistory<EditSnapshot>()
        history.record(EditSnapshot(EditFixtures.blank()))
        let draft = QuickEditDraft(takeID: UUID(), edit: EditFixtures.everything(), playhead: 3, history: history, savedAt: .now)
        try store.save(draft)
        let file = directory.appending(path: "\(draft.takeID.uuidString).json")
        var saved = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        saved["history"] = ["past": "steps from the future"]
        try JSONSerialization.data(withJSONObject: saved).write(to: file)
        let read = try #require(store.draft(for: draft.takeID))
        #expect(read.edit.texts.count == 1)
        #expect(read.playhead == 3)
        #expect(!read.history.canUndo)
    }

    // MARK: - Helpers

    private static func take() -> Take {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = EditFixtures.duration
        take.isEdited = true
        take.edit = EditFixtures.everything()
        return take
    }

    private static func savedTakes() -> [URL] {
        (Bundle(for: BundleToken.self).urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("saved-takes-") }
    }

    /// This version's take as JSON, its edit changed the way a newer version might have written it.
    private static func newer(_ change: (inout [String: Any]) -> Void) throws -> Data {
        let data = try JSONEncoder.library.encode([take()])
        var takes = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        var edit = try #require(takes[0]["edit"] as? [String: Any])
        change(&edit)
        takes[0]["edit"] = edit
        return try JSONSerialization.data(withJSONObject: takes)
    }

    private static func change(_ edit: inout [String: Any], _ key: String, _ index: Int, _ update: (inout [String: Any]) -> Void) {
        var list = edit[key] as? [[String: Any]] ?? []
        update(&list[index])
        edit[key] = list
    }

    /// A Takes folder holding `takes.json`.
    private static func library(with data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: "takes.json"))
        return directory
    }

    private static func keptCopies(in directory: URL) -> Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? [])
            .filter { $0.hasPrefix("takes-kept-") }.count
    }
}
