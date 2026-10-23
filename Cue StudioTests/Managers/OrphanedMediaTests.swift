//
//  OrphanedMediaTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The edits' media nothing names any more go a week after they last changed, with their sidecars; a file any take, kept
/// copy or draft (even one that can't be read as an edit) mentions stays, and so does anything newer.
@Suite("Orphaned edit media")
struct OrphanedMediaTests {
    private static let launch = Date(timeIntervalSince1970: 1_800_000_000)
    private static let old = launch.addingTimeInterval(-8 * 24 * 60 * 60)
    private static let recent = launch.addingTimeInterval(-2 * 24 * 60 * 60)

    @Test func onlyOldFilesNothingNamesAreOrphans() {
        let files = [
            "kept.mov": Self.old, "lost.mov": Self.old, "new.mov": Self.recent,
            "kept.mov.cuemotion": Self.old, "lost.mov.cuemotion": Self.old, "gone.m4a.cuebeats": Self.old,
        ]
        let orphans = EditStorageCleaner.orphanedMedia(files: files, launchedAt: Self.launch) { $0 == "kept.mov" }
        #expect(orphans == ["lost.mov", "gone.m4a.cuebeats"])
    }

    @Test func theSweepKeepsWhatAnySavedFileMentions() throws {
        let root = URL.temporaryDirectory.appending(path: "orphans \(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let media = root.appending(path: "EditMedia", directoryHint: .isDirectory)
        let takes = root.appending(path: "Takes", directoryHint: .isDirectory)
        let drafts = root.appending(path: "QuickEditDrafts", directoryHint: .isDirectory)
        for folder in [media, takes, drafts] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let names = ["in-a-take.mov", "in-a-kept-copy.jpg", "in-an-unreadable-draft.m4a", "nobody.mov", "nobody-recent.mov"]
        for name in names {
            let url = media.appending(path: name)
            try Data("x".utf8).write(to: url)
            let date = name == "nobody-recent.mov" ? Self.recent : Self.old
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path(percentEncoded: false))
        }
        try Data(#"[{"edit":{"media":[{"fileName":"in-a-take.mov"}]}}]"#.utf8).write(to: takes.appending(path: "takes.json"))
        try Data(#"[{"fileName":"in-a-kept-copy.jpg"}"#.utf8).write(to: takes.appending(path: "takes-kept-2026.json"))
        try Data(#"{"history":"from a newer version","voiceOvers":["in-an-unreadable-draft.m4a"]"#.utf8)
            .write(to: drafts.appending(path: "\(UUID().uuidString).json"))

        EditStorageCleaner.sweepOrphanedMedia(launchedAt: Self.launch, media: media, support: root)

        let left = Set(try FileManager.default.contentsOfDirectory(atPath: media.path(percentEncoded: false)))
        #expect(left == ["in-a-take.mov", "in-a-kept-copy.jpg", "in-an-unreadable-draft.m4a", "nobody-recent.mov"])

        // A saved file that can't be read as text stops the whole sweep.
        let another = media.appending(path: "nobody-either.mov")
        try Data("x".utf8).write(to: another)
        try FileManager.default.setAttributes([.modificationDate: Self.old], ofItemAtPath: another.path(percentEncoded: false))
        try Data([0xFF, 0xFE, 0xFD]).write(to: drafts.appending(path: "broken.json"))
        EditStorageCleaner.sweepOrphanedMedia(launchedAt: Self.launch, media: media, support: root)
        #expect(FileManager.default.fileExists(atPath: another.path(percentEncoded: false)))
    }
}
