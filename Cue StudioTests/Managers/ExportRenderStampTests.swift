//
//  ExportRenderStampTests.swift
//  Cue StudioTests
//

import Darwin
import Foundation
import Testing
@testable import Cue_Studio

/// What a file was drawn with beyond the edit: the same inputs give the same stamp, and a font that arrived, an imported font's other
/// file, a media file that changed or a newer Cue each give another. Kept on the file itself (`ExportedFileRecord`).
@Suite("Export render stamp")
struct ExportRenderStampTests {
    /// An edit with a text in a script library's family (it needs that pack), a text in an imported family, and a voice-over.
    private var edit: TakeEdit {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var library = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 0, end: 2))
        library.text = "Hello"
        library.font = .pack(FontPackManifest.bundled.packs[0].id)
        var branded = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 2, end: 4))
        branded.text = "Hello"
        branded.font = .custom("My Brand Sans")
        edit.texts = [library, branded]
        edit.voiceOvers = [VoiceOverClip(fileName: "voice.caf", duration: 2, anchor: 1)]
        return edit
    }

    private func stamp(
        _ edit: TakeEdit?, build: String = "1.0(1)", drawn: Bool = true, customFile: String? = "brand.otf", media: String = "100@1"
    ) -> String {
        ExportRenderStamp.make(
            edit: edit, han: .chineseSimplified, build: build, isDrawn: { _ in drawn }, customFile: { _ in customFile }, mediaStamp: { _ in media }
        )
    }

    @Test func theSameInputsGiveTheSameStamp() {
        #expect(stamp(edit) == stamp(edit))
    }

    @Test func eachDependencyChangesIt() {
        let base = stamp(edit)
        #expect(stamp(edit, drawn: false) != base, "A script font missing, then there")
        #expect(stamp(edit, customFile: nil) != base, "An imported font gone")
        #expect(stamp(edit, customFile: "brand-v2.otf") != base, "An imported font replaced")
        #expect(stamp(edit, media: "300@2") != base, "A media file changed")
        #expect(stamp(edit, media: "missing") != base, "A media file gone")
        #expect(stamp(edit, build: "1.1(2)") != base, "A newer Cue")
    }

    @Test func theEditNamesWhatItDependsOn() {
        let text = stamp(edit)
        #expect(text.contains("pack:"), "The Japanese words need a script family")
        #expect(text.contains("custom:My Brand Sans/"))
        #expect(text.contains("media:voice.caf="))
        #expect(stamp(nil) == "build:1.0(1)")
    }

    @Test func whatWasDrawnInTheSystemFaceReadsAsMissingNow() throws {
        let need = try #require(FontPackNeeds.needs(in: edit, han: .chineseSimplified).first)
        let result = ExportResult(url: URL.temporaryDirectory, unavailableFonts: [need], missingCustomFamilies: ["My Brand Sans"])
        let drawn = ExportRenderStamp.drawn(edit: edit, result: result)
        // On this simulator the pack isn't registered nor the family imported: drawn and current agree, so the file is reused…
        #expect(drawn == ExportRenderStamp.current(edit: edit))
        // …and a file drawn with them reads differently.
        #expect(drawn.contains("=system"))
    }

    @Test func theRecordTravelsWithTheFile() throws {
        let file = URL.temporaryDirectory.appending(path: "Cue-test-\(UUID().uuidString.prefix(8)).mov")
        try Data([0]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(ExportedFileRecord.read(at: file) == nil, "A file without a record is never reused")
        let record = ExportedFileRecord(renderStamp: "build:1", fontFallback: .notDownloaded)
        #expect(record.write(to: file))
        #expect(ExportedFileRecord.read(at: file) == record)
        // Gone with the file.
        try FileManager.default.removeItem(at: file)
        #expect(ExportedFileRecord.read(at: file) == nil)
    }
}
