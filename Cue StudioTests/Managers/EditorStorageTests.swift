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
