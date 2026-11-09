//
//  ExportFileNameTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ExportFileName")
struct ExportFileNameTests {
    @Test func theNameIsTheScriptAndTheTake() {
        #expect(ExportFileName.name(title: "Morning routine", takeNumber: 2) == "Morning routine · Take 2.mov")
    }

    @Test func aTitleBecomesOneSafeLine() {
        #expect(ExportFileName.sanitized("3 tips: part 1/2\nnow") == "3 tips part 1 2 now")
        #expect(ExportFileName.sanitized("  ...  ") == "Cue video")
        #expect(ExportFileName.sanitized(String(repeating: "a", count: 90)).count == ExportFileName.maxTitleLength)
    }

    @Test func twoVideosOfOneTakeNeverShareAPath() throws {
        let folder = URL.temporaryDirectory.appending(path: "ExportFileNameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appending(path: "Cue-aaaa.mov")
        let second = folder.appending(path: "Cue-bbbb.mov")
        try Data("1".utf8).write(to: first)
        try Data("2".utf8).write(to: second)
        #expect(ExportedFileRecord(renderStamp: "s", fontFallback: nil).write(to: first))

        let named = ExportFileName.rename(first, title: "Hello", takeNumber: 1)
        let again = ExportFileName.rename(second, title: "Hello", takeNumber: 1)
        // Both named alike, each in its own folder: never the same path.
        #expect(named.lastPathComponent == "Hello · Take 1.mov" && again.lastPathComponent == "Hello · Take 1.mov")
        #expect(named != again && FileManager.default.fileExists(atPath: named.path) && FileManager.default.fileExists(atPath: again.path))
        #expect(ExportedFileRecord.read(at: named)?.renderStamp == "s")
    }
}
