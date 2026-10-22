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

    /// Eye Contact was removed (22/10/2026): an edit saved with it on still opens, as the same edit without it, and exports
    /// like one that never had it.
    @Test func anEditSavedWithEyeContactOpensAndExportsLikeOneWithout() throws {
        let edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        var saved = try #require(try JSONSerialization.jsonObject(with: JSONEncoder.library.encode(edit)) as? [String: Any])
        saved["eyeContact"] = ["engine": 2, "strength": 0.6]
        let opened = try JSONDecoder.library.decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(opened == edit)
        let prints = [edit, opened].map { fingerprint(ExportOptions(aspect: .portrait, edit: $0, burnsInCaptions: false, shortSide: nil)) }
        #expect(prints[0] == prints[1])
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
