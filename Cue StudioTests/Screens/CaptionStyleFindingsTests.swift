//
//  CaptionStyleFindingsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the review of Caption style found before Phase 3, written as the behaviour it should have (each failed on the code
/// before it): another style kept the size, a copied look saved as a style showed twice, and erasing everything left the
/// captions' style behind.
@MainActor
@Suite("Caption style findings")
struct CaptionStyleFindingsTests {
    private func makeViewModel(styles: FakeTextStyleStore = FakeTextStyleStore()) async -> QuickEditViewModel {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: styles
        )
        await viewModel.prepare()
        viewModel.changeEdit { $0.captions = [CaptionCue(text: "Okay real talk", start: 1, end: 2, origin: .manual)] }
        return viewModel
    }

    @Test func anotherPresetKeepsTheSizeTheCreatorSet() async {
        let viewModel = await makeViewModel()
        viewModel.captions.setCaptionPointSize(24)
        let size = viewModel.captions.captionPointSize
        viewModel.captions.pickCaptionTheme(.pop)
        #expect(viewModel.captions.captionPointSize == size)
    }

    @Test func aCopiedLookSavedAsAStyleIsOneCardNotTwo() async {
        let styles = FakeTextStyleStore()
        let viewModel = await makeViewModel(styles: styles)
        viewModel.changeEdit { $0.captionCollection?.customLook = TypePreset.launch.look(for: .caption) }
        #expect(viewModel.captions.currentCaptionCard != nil, "the copied look shows as this video's")
        viewModel.captions.saveCaptionStyle(named: "Launch")
        let cards = viewModel.captions.captionCardSections(.all).flatMap(\.cards)
        let picked = cards.filter(\.isSelected)
        // Saved from a look an earlier version copied: the saved style keeps it as it was, so it is the one card marked.
        #expect(picked.count == 1, "\(picked.map(\.name)) marked")
        #expect(viewModel.captions.currentCaptionCard == nil)
    }

    @Test func erasingEverythingTakesTheCaptionsStyleToo() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = TextStyleStore(defaults: defaults.defaults)
        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        edit.captionCollection = CaptionSettings(theme: .pop)
        defaults.defaults.set(try? JSONEncoder().encode(MyCaptionStyle(of: edit)), forKey: DefaultsKey.myCaptionStyle)
        #expect(store.captionStyles.styles.count == 1, "the style saved before the library is read into it")
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: []))
        let eraser = DataEraserService(
            library: library, takes: takes, drafts: FakeDraftStore(), logbook: LogbookService(defaults: defaults.defaults),
            brands: BrandStore(repository: InMemoryBrandRepository()), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), defaults: defaults.defaults, eraseLooseFiles: {}
        )
        eraser.eraseEverything()
        #expect(TextStyleStore(defaults: defaults.defaults).captionStyles.styles.isEmpty)
        #expect(defaults.defaults.object(forKey: DefaultsKey.myCaptionStyle) == nil)
    }
}
