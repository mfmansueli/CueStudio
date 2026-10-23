//
//  EditorFailureReportTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// An editor or export failure is written down by what failed and the iPhone's state, never by what the creator made: Cue's
/// errors by type and case (without what a case carries), the system's by domain and code with the one under it.
@MainActor
@Suite("Editor failure reports")
struct EditorFailureReportTests {
    @Test func cuesErrorsAreNamedByTheirCaseAlone() {
        #expect(EditorFailureReport.reason(of: VideoExportError.tooWarm).reason == "VideoExportError.tooWarm")
        #expect(EditorFailureReport.reason(of: ExportPreflightError.notEnoughSpace(megabytes: 300)).reason == "ExportPreflightError.notEnoughSpace")
    }

    @Test func theSystemsErrorsKeepTheErrorUnderThem() {
        let under = NSError(domain: NSOSStatusErrorDomain, code: -12_785)
        let error = NSError(domain: "AVFoundationErrorDomain", code: -11_800, userInfo: [NSUnderlyingErrorKey: under, "path": "/private/Comidas.mov"])
        let (reason, underlying) = EditorFailureReport.reason(of: error)
        #expect(reason == "AVFoundationErrorDomain -11800")
        #expect(underlying == "NSOSStatusErrorDomain -12785")
    }

    @Test func aCancellationIsntAFailure() {
        #expect(EditorFailureReport.make(CancellationError(), operation: "export") == nil)
    }

    @Test func theReportCarriesCountsNeverTheEdit() throws {
        let edit = EditFixtures.everything()
        let error = NSError(domain: "AVFoundationErrorDomain", code: -11_800, userInfo: [NSFilePathErrorKey: "/private/Comidas.mov"])
        let report = try #require(EditorFailureReport.make(error, operation: "export", edit: edit))
        #expect(report.issue == "Editor.export.AVFoundationErrorDomain -11800")
        #expect(report.keys["clips"] == "\(edit.timeline.segments.count)")
        #expect(report.keys["layers"] == "5")
        let written = report.line + report.keys.values.joined()
        for words in ["Comidas", "Oi", ".mov", ".m4a", ".jpg"] { #expect(!written.contains(words), "\(words) was written down") }
    }

    @Test func aFrameThatCantBeFrozenIsWrittenDown() async {
        let editor = FakeTakeEditor()
        editor.stillClipFails = true
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        var failures: [EditorFailureReport] = []
        viewModel.reportFailure = { failures.append($0) }
        await viewModel.freezeFrame()
        #expect(failures.map(\.operation) == ["freezeFrame"])
        #expect(failures.first?.size?.clips == 1)
    }
}
