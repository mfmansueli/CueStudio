//
//  QuickEditFontCheckTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Is it ready to post?" says when some words would come out in the system's face, before the creator picks where the video goes
/// (plan §15: fonts unavailable, told before exporting, not only in the result).
@MainActor
struct QuickEditFontCheckTests {
    private func makeViewModel(font: TextOverlayFont?) async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 12
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        // The script families come from a source that never delivers (`OfflineFontPackSource`, the default here).
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback()
        )
        await viewModel.prepare()
        if let font {
            viewModel.changeEdit { edit in
                var title = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 1, end: 4))
                title.text = "Three habits"
                title.font = font
                edit.texts = [title]
            }
        }
        return viewModel
    }

    @Test func wordsInTheirOwnFontsSayNothing() async {
        #expect(await makeViewModel(font: nil).fontsNotReady == nil)
        #expect(await makeViewModel(font: .classic).fontsNotReady == nil)
    }

    @Test func anImportedFontThatIsGoneIsToldWithWhatFixesIt() async {
        let viewModel = await makeViewModel(font: .custom("A Family Never Imported Here"))
        #expect(viewModel.fontsNotReady == .notOnThisIPhone)
        #expect(EditorDoneFontNote.text(for: .notOnThisIPhone).contains("import it again"))
    }

    @Test func aScriptFontNotDownloadedYetIsTold() async throws {
        let pack = try #require(FontPackManifest.bundled.packs.first)
        let viewModel = await makeViewModel(font: .pack(pack.id))
        #expect(viewModel.fontsNotReady == .notDownloaded)
        #expect(EditorDoneFontNote.text(for: .notDownloaded).contains("stay online"))
    }
}
