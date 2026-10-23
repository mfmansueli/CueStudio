//
//  EditorStorageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Space and files: an export asks for room before it starts, the cleaner takes only sound files of past launches (never the
/// edits' media), the sound cache never deletes a file another key still points at, and a
/// MetricKit report carries no more than its kind, size and a cut call stack.
@Suite("Editor storage")
struct EditorStorageTests {
    @Test func anExportAsksForTwiceItsSizeAndAMargin() {
        #expect(StorageSpace.needed(forExportOf: 100) == 200_000_000 + StorageSpace.margin)
        #expect(StorageSpace.shortfall(forExportOf: 100, available: 400_000_000) == nil)
        #expect(StorageSpace.shortfall(forExportOf: 100, available: 300_000_000) == 50)
        #expect(StorageSpace.shortfall(forExportOf: 100, available: nil) == nil)
    }

    @Test func onlyPastLaunchesSoundFilesGo() {
        let launch = Date()
        let files = [
            "Cue-audio-1234.m4a": launch.addingTimeInterval(-60), "Cue-mix-1.caf": launch.addingTimeInterval(5),
            "Cue-abcd1234.mov": launch.addingTimeInterval(-60), "take-1.mov": launch.addingTimeInterval(-60),
        ]
        #expect(EditStorageCleaner.staleSounds(files: files, launchedAt: launch) == ["Cue-audio-1234.m4a"])
    }

    /// Eye Contact's analyses (removed 22/10/2026) go from next to the recordings at launch; the recordings and their motion
    /// analyses stay.
    @Test func aRemovedToolsAnalysesGoAndTheRecordingsStay() async throws {
        let folder = URL.temporaryDirectory.appending(path: "retired-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let recording = folder.appending(path: "take.mov")
        let kept = [recording, MotionAnalysisStore.url(forRecording: recording)]
        for file in kept + [recording.appendingPathExtension("cueeyes")] { try Data([1]).write(to: file) }

        await EditStorageCleaner.clean(launchedAt: .now, recordingFolders: [folder])

        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(Set(left) == Set(kept.map(\.lastPathComponent)))
    }

    @Test func aLevelThatChangedNothingNeverDeletesItsInput() async throws {
        let cache = RecordingSoundCache()
        let input = URL.temporaryDirectory.appending(path: "level-input-\(UUID().uuidString).caf")
        try FileManager.default.copyItem(at: try SoundEffectSynth.file(for: .whoosh), to: input)
        defer { try? FileManager.default.removeItem(at: input) }
        // No change: the same file comes back, under its own key.
        #expect(try await cache.leveled(input, gain: 0) == input)
        // Enough other levels to push that key out.
        var made: [URL] = []
        for step in 1...(RecordingSoundCache.fileLimit + 1) {
            made.append(try await cache.leveled(input, gain: -Float(step)))
        }
        defer { made.forEach { try? FileManager.default.removeItem(at: $0) } }
        #expect(FileManager.default.fileExists(atPath: input.path(percentEncoded: false)))
        // Past the limit, files used just now stay: a montage of many recordings needs them all at once.
        #expect(made.allSatisfy { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) })
    }

    @Test func treatmentsPastTheByteBudgetGoOldestFirst() async throws {
        let input = try TestTone.make(seconds: 2)
        defer { try? FileManager.default.removeItem(at: input) }
        let size = Int64(try #require(try input.resourceValues(forKeys: [.fileSizeKey]).fileSize))
        // Room for two levels of it; nothing is held as in use.
        let cache = RecordingSoundCache(byteBudget: size * 5 / 2, keepsInUse: 0)
        var made: [URL] = []
        for step in 1...4 { made.append(try await cache.leveled(input, gain: -Float(step))) }
        defer { made.forEach { try? FileManager.default.removeItem(at: $0) } }
        let left = made.map { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
        #expect(left == [false, false, true, true])
        #expect(FileManager.default.fileExists(atPath: input.path(percentEncoded: false)))
        #expect(RecordingSoundCache.byteBudget(freeSpace: 40_000_000_000) == 3_000_000_000)
        #expect(RecordingSoundCache.byteBudget(freeSpace: 4_000_000_000) == 1_000_000_000)
        #expect(RecordingSoundCache.byteBudget(freeSpace: 1_000_000_000) == 512_000_000)
    }

    @Test func aDiagnosticCarriesItsKindSizeAndACutStack() {
        let stack = Data(repeating: UInt8(ascii: "a"), count: DeviceDiagnosticReport.callStackLimit + 500)
        let report = DeviceDiagnosticReport(kind: .hang, amount: 1_200, build: "42", system: "iPhone OS 27.0", callStack: stack)
        #expect(report.domain == "MetricKit.hang")
        #expect(report.callStack.count == DeviceDiagnosticReport.callStackLimit)
        #expect(report.keys["amount"] as? Int == 1_200)
    }
}

/// A hot iPhone: the export says it takes longer, nothing else changes.
@Suite("Device heat")
struct DeviceHeatTests {
    @Test func onlyAHotIPhoneGetsTheNote() {
        #expect(DeviceHeat.exportNote(for: .nominal) == nil)
        #expect(DeviceHeat.exportNote(for: .fair) == nil)
        #expect(DeviceHeat.exportNote(for: .serious) != nil)
        #expect(DeviceHeat.exportNote(for: .critical) != nil)
    }
}
