//
//  ExportFingerprintTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ExportFingerprint")
struct ExportFingerprintTests {
    private let take = UUID()
    private let source = URL(fileURLWithPath: "/nonexistent/take.mov")

    private func fingerprint(_ options: ExportOptions, take: UUID? = nil) -> String {
        ExportFingerprint.make(takeID: take ?? self.take, source: source, options: options)
    }

    @Test func theSameInputsGiveTheSameFingerprint() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline.trimEnd(to: 10)
        let options = ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true, shortSide: 1080)
        #expect(fingerprint(options) == fingerprint(options))
        #expect(fingerprint(options).count == 64)
    }

    @Test func anyChangeToTheEditOrSettingsChangesIt() {
        let edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        var trimmed = edit
        trimmed.timeline.trimEnd(to: 10)
        let base = ExportOptions(aspect: .portrait, edit: edit)
        let changed: [ExportOptions] = [
            ExportOptions(aspect: .portrait, edit: trimmed),
            ExportOptions(aspect: .square, edit: edit),
            ExportOptions(aspect: .portrait, edit: edit, burnsInCaptions: true),
            ExportOptions(aspect: .portrait, edit: edit, shortSide: 720),
            ExportOptions(aspect: .portrait, edit: edit, frameRate: 60),
            ExportOptions(aspect: .portrait, edit: nil),
        ]
        for options in changed {
            #expect(fingerprint(options) != fingerprint(base))
        }
        #expect(fingerprint(base, take: UUID()) != fingerprint(base))
    }

    @Test func aDifferentRecordingUnderTheSameNameIsADifferentExport() throws {
        let url = URL.temporaryDirectory.appending(path: "fingerprint-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        let options = ExportOptions(aspect: .portrait)
        try Data([1]).write(to: url)
        let before = ExportFingerprint.make(takeID: take, source: url, options: options)
        try Data([1, 2, 3]).write(to: url)
        let after = ExportFingerprint.make(takeID: take, source: url, options: options)
        #expect(before != after)
    }
}
