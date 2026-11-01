//
//  TakeOrphanSweepTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Take videos nothing names (B12): a week from the first time each is found so, only when everything was read, never what is in use; deletions
/// written down finish at the next launch.
@MainActor
struct TakeOrphanSweepTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private var old: Date { now.addingTimeInterval(-90 * 24 * 60 * 60) }
    private let week = TakeOrphanSweep.graceAge

    private func plan(
        _ files: [String: Date], named: Set<String> = [], inUse: Set<String> = [], sightings: [String: Date] = [:], pending: Set<String> = []
    ) -> TakeOrphanSweep.Plan {
        TakeOrphanSweep.plan(files: files, named: { named.contains($0) }, inUse: inUse, sightings: sightings, pending: pending, now: now)
    }

    // MARK: - The plan

    /// A video made long ago but found nameless only now waits its week from now: the file's date isn't when it lost its take.
    @Test func theWeekCountsFromTheFirstSightingNotTheFileDate() {
        let result = plan(["A.mov": old])
        #expect(result.doomed.isEmpty)
        #expect(result.sightings == ["A.mov": now])
    }

    @Test func aWeekAfterItsFirstSightingItGoesWithItsAnalysis() {
        let result = plan(["A.mov": old, "A.mov.cuemotion": old], sightings: ["A.mov": now.addingTimeInterval(-week)])
        #expect(result.doomed == ["A.mov", "A.mov.cuemotion"])
        #expect(result.sightings.isEmpty)
    }

    /// Named again (a take, a saved record): its sighting is forgotten, and a deletion written down for it no longer runs.
    @Test func aNamedVideoIsLeftAndItsPendingDeletionResolved() {
        let result = plan(["A.mov": old], named: ["A.mov"], sightings: ["A.mov": now.addingTimeInterval(-2 * week)], pending: ["A.mov"])
        #expect(result.doomed.isEmpty && result.sightings.isEmpty)
        #expect(result.resolved == ["A.mov"])
    }

    /// A deleted take's video while its Undo can still bring it back: left exactly as it is, its deletion still written down.
    @Test func aVideoInUseIsLeftAsItIs() {
        let first = now.addingTimeInterval(-2 * week)
        let result = plan(["A.mov": old], inUse: ["A.mov"], sightings: ["A.mov": first], pending: ["A.mov"])
        #expect(result.doomed.isEmpty && result.resolved.isEmpty)
        #expect(result.sightings == ["A.mov": first])
    }

    /// Changed in the last minutes (a take moved in, not filed yet): never this launch, whatever was decided.
    @Test func aFileChangedLatelyWaits() {
        let recent = now.addingTimeInterval(-60)
        let first = now.addingTimeInterval(-2 * week)
        let result = plan(["A.mov": recent], sightings: ["A.mov": first], pending: ["A.mov"])
        #expect(result.doomed.isEmpty && result.resolved.isEmpty)
        #expect(result.sightings == ["A.mov": first])
    }

    /// A deletion written down (a deleted take whose Undo was on screen when Cue ended) finishes without the week.
    @Test func aPendingDeletionFinishesWithoutTheWeek() {
        #expect(plan(["A.mov": old], pending: ["A.mov"]).doomed == ["A.mov"])
    }

    @Test func onlyVideosAndTheirAnalysesAreLookedAt() {
        let result = plan(["takes.json": old, "takes-kept-2026.json": old, "notes.txt": old, "B.cuemotion": old], pending: ["takes.json"])
        #expect(result.doomed.isEmpty && result.sightings.isEmpty)
    }

    /// An analysis whose video is gone and named by nothing is a nameless file of its own; one whose take still exists is left.
    @Test func anAnalysisWithoutItsVideoWaitsItsOwnWeek() {
        #expect(plan(["A.mov.cuemotion": old]).sightings == ["A.mov.cuemotion": now])
        #expect(plan(["A.mov.cuemotion": old], named: ["A.mov"]).sightings.isEmpty)
    }

    @Test func aPendingDeletionOfAFileAlreadyGoneIsResolved() {
        #expect(plan([:], pending: ["A.mov"]).resolved == ["A.mov"])
    }

    // MARK: - The sweep, on disk

    @MainActor
    private struct Disk {
        let support: URL
        let folder: URL
        let defaults = TestDefaults()

        init() throws {
            support = FileManager.default.temporaryDirectory.appending(path: "orphan-sweep-\(UUID().uuidString)", directoryHint: .isDirectory)
            folder = support.appending(path: "Takes", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        var pending: PendingTakeDeletions { PendingTakeDeletions(defaults: defaults.defaults) }

        func library() -> TakeLibraryService {
            let takes = TakeLibraryService(repository: LocalTakeRepository(directory: folder), pendingDeletions: pending)
            takes.load()
            return takes
        }

        /// A recording handed to the library, as the camera does.
        func record(into takes: TakeLibraryService) throws -> Take {
            let file = support.appending(path: "take-\(UUID().uuidString).mov")
            try Data("video".utf8).write(to: file)
            return try takes.addTake(fileAt: file, duration: 5, script: nil, camera: CameraSettings())
        }

        func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: folder.appending(path: name).path(percentEncoded: false)) }

        func tearDown() {
            try? FileManager.default.removeItem(at: support)
            defaults.tearDown()
        }
    }

    /// Past the settle time (a file's dates are "now" in a test).
    private var later: Date { Date().addingTimeInterval(TakeOrphanSweep.settleAge + 60) }

    /// A take deleted while its Undo was on screen, Cue ended before the Undo left: the next launch removes its video.
    @Test func aDeletionCutShortFinishesAtTheNextLaunch() async throws {
        let disk = try Disk()
        defer { disk.tearDown() }
        let takes = disk.library()
        let take = try disk.record(into: takes)
        let kept = try disk.record(into: takes)
        let removed = try #require(takes.remove(take.id))
        takes.awaitPurge(removed)
        #expect(disk.pending.names == [take.fileName])
        // While the Undo is on screen, the sweep leaves it.
        #expect(await TakeOrphanSweep.sweep(takes: takes, pending: disk.pending, folder: disk.folder, support: disk.support, now: later).isEmpty)
        // Next launch.
        let relaunched = disk.library()
        let gone = await TakeOrphanSweep.sweep(takes: relaunched, pending: disk.pending, folder: disk.folder, support: disk.support, now: later)
        #expect(gone == [take.fileName])
        #expect(!disk.exists(take.fileName) && disk.exists(kept.fileName))
        #expect(disk.pending.names.isEmpty)
    }

    /// Undo brought the take back: its deletion isn't written down any more.
    @Test func undoTakesTheDeletionOffTheList() throws {
        let disk = try Disk()
        defer { disk.tearDown() }
        let takes = disk.library()
        let take = try disk.record(into: takes)
        let removed = try #require(takes.remove(take.id))
        takes.awaitPurge(removed)
        takes.restore(removed)
        #expect(disk.pending.names.isEmpty)
    }

    /// A nameless video: seen the first time, kept a week, then removed.
    @Test func aNamelessVideoGoesAWeekAfterItWasFirstFound() async throws {
        let disk = try Disk()
        defer { disk.tearDown() }
        let takes = disk.library()
        _ = try disk.record(into: takes)
        try Data("lost".utf8).write(to: disk.folder.appending(path: "LOST.mov"))
        #expect(await TakeOrphanSweep.sweep(takes: takes, pending: disk.pending, folder: disk.folder, support: disk.support, now: later).isEmpty)
        #expect(disk.exists("LOST.mov"))
        let gone = await TakeOrphanSweep.sweep(
            takes: takes, pending: disk.pending, folder: disk.folder, support: disk.support, now: later.addingTimeInterval(TakeOrphanSweep.graceAge)
        )
        #expect(gone == ["LOST.mov"] && !disk.exists("LOST.mov"))
        #expect(disk.defaults.defaults.dictionary(forKey: DefaultsKey.takeOrphanSightings) == nil)
    }

    /// A record that can't be read might name it, and a copy kept of a damaged library does name it: nothing goes.
    @Test func anUnreadableRecordOrAKeptCopyKeepsIt() async throws {
        let disk = try Disk()
        defer { disk.tearDown() }
        let takes = disk.library()
        try Data("lost".utf8).write(to: disk.folder.appending(path: "LOST.mov"))
        disk.pending.add(["LOST.mov"])
        let unreadable = disk.support.appending(path: "Library/broken.json")
        try FileManager.default.createDirectory(at: unreadable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0xFD]).write(to: unreadable)
        #expect(await TakeOrphanSweep.sweep(takes: takes, pending: disk.pending, folder: disk.folder, support: disk.support, now: later).isEmpty)
        try FileManager.default.removeItem(at: unreadable)
        try Data(#"[{"fileName":"LOST.mov"}]"#.utf8).write(to: disk.folder.appending(path: "takes-kept-2026-11-01.json"))
        #expect(await TakeOrphanSweep.sweep(takes: takes, pending: disk.pending, folder: disk.folder, support: disk.support, now: later).isEmpty)
        #expect(disk.exists("LOST.mov"))
        #expect(disk.pending.names.isEmpty, "Named by the kept copy: the deletion no longer stands")
    }

    /// A library that couldn't be read (the iPhone locked since launch): every video might be a take's, so nothing is even looked at.
    @Test func aLibraryNotReadSweepsNothing() async throws {
        let disk = try Disk()
        defer { disk.tearDown() }
        try FileManager.default.createDirectory(at: disk.folder.appending(path: "takes.json"), withIntermediateDirectories: true)
        let takes = disk.library()
        #expect(!takes.isRead)
        try Data("lost".utf8).write(to: disk.folder.appending(path: "LOST.mov"))
        disk.pending.add(["LOST.mov"])
        #expect(await TakeOrphanSweep.sweep(takes: takes, pending: disk.pending, folder: disk.folder, support: disk.support, now: later).isEmpty)
        #expect(disk.exists("LOST.mov") && disk.pending.names == ["LOST.mov"])
    }
}
