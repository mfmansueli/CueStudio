//
//  QuickEditCaptionStyleLibraryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The creator's saved caption styles: saved with a name and worn by another video in one undo step, keeping that video's size,
/// place and format unless the style's own are asked for; renamed, updated, duplicated, favored, picked for new captions and
/// deleted with Undo, never changing a video already made.
@MainActor
@Suite("Quick edit caption style library")
struct QuickEditCaptionStyleLibraryTests {
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
        return viewModel
    }

    private func line(_ viewModel: QuickEditViewModel) {
        viewModel.changeEdit { $0.captions = [CaptionCue(text: "Oi tudo bem", start: 1, end: 2, origin: .manual)] }
    }

    @Test func savedOnceItGoesOnAnotherVideoInOneUndoStepKeepingThatVideosLayout() async throws {
        let styles = FakeTextStyleStore()
        let first = await makeViewModel(styles: styles)
        line(first)
        first.captions.pickCaptionTheme(.pop)
        first.captions.setCaptionPointSize(24)
        first.captions.saveCaptionStyle(named: "Violet big")
        let saved = try #require(styles.captionStyles.styles.first)
        #expect(saved.name == "Violet big" && saved.look.settings.theme == .pop)
        #expect(first.captions.captionCardSections(.mine).first?.cards.first?.isSelected == true)

        let second = await makeViewModel(styles: styles)
        line(second)
        let margins = second.edit.captionCollection?.safeMargins
        let size = second.captions.captionPointSize
        second.captions.applySavedCaptionStyle(saved.id)
        #expect(second.edit.captionCollection?.theme == .pop)
        #expect(second.edit.captionCollection?.safeMargins == margins)
        #expect(second.captions.captionPointSize == size, "the video keeps its size")
        #expect(second.captions.captionFullStyleOffer == "Violet big")
        second.captions.useFullCaptionStyle()
        #expect(second.captions.captionPointSize == 24)
        #expect(second.captions.captionFullStyleOffer == nil)
        second.undo()
        second.undo()
        #expect(second.edit.captionCollection?.theme == .cue)
    }

    /// A style comes back whole: "Back to its look" takes away Adjust's changes, the highlight color and the motion picked
    /// in Animation, in one undo step, and its card is the one marked again; the size the creator gave stays.
    @Test func backToTheStylesLookBringsItBackAsItsCardShowsIt() async throws {
        let viewModel = await makeViewModel()
        line(viewModel)
        let captions = viewModel.captions
        captions.pickCaptionTheme(.glide)
        captions.setCaptionPointSize(24)
        let size = captions.captionPointSize
        captions.setCaptionEntry(.rise)
        captions.setCaptionSpokenHighlight(.pop)
        captions.setCaptionAccent(.red)
        #expect(captions.changedCaptionLookCount == 2, "the highlight color and the motion")
        #expect(captions.currentCaptionCard != nil, "a changed motion is this video's own look")

        captions.resetCaptionLook()
        let settings = try #require(viewModel.edit.captionCollection)
        #expect(settings.look == CaptionSettings(theme: .glide).look)
        #expect(captions.changedCaptionLookCount == 0)
        #expect(captions.currentCaptionCard == nil)
        #expect(captions.captionCardSections(.all).flatMap(\.cards).first { $0.isSelected }?.kind == .builtIn(.glide))
        #expect(captions.captionPointSize == size, "the size stays")
        #expect(viewModel.edit.captionAnimation == CaptionSettings(theme: .glide).motion?.nearestAnimation)

        viewModel.undo()
        #expect(viewModel.edit.captionCollection?.motion?.spoken == .pop)
        #expect(viewModel.edit.captionCollection?.accent == .red)
    }

    @Test func editingOrDeletingASavedStyleNeverChangesAVideoThatWearsIt() async throws {
        let styles = FakeTextStyleStore()
        let viewModel = await makeViewModel(styles: styles)
        line(viewModel)
        viewModel.captions.pickCaptionTheme(.paper)
        viewModel.captions.saveCaptionStyle(named: "Paper")
        let id = try #require(viewModel.captions.captionStyles.styles.first?.id)
        let worn = viewModel.edit.captionCollection
        viewModel.captions.pickCaptionTheme(.comic)
        viewModel.captions.updateCaptionStyle(id)
        viewModel.undo()
        #expect(viewModel.edit.captionCollection?.theme == .paper, "undo took the video back, not the saved style")
        #expect(styles.captionStyles.style(id)?.look.settings.theme == .comic)
        viewModel.captions.deleteCaptionStyle(id)
        #expect(viewModel.edit.captionCollection?.look == worn?.look)
        #expect(styles.captionStyles.styles.isEmpty)
        viewModel.toast.action?.perform()
        #expect(styles.captionStyles.style(id)?.name == "Paper")
    }

    @Test func aSavedStyleIsRenamedDuplicatedAndFavoredAndOneOfCuesIsSavedAsMine() async throws {
        let styles = FakeTextStyleStore()
        let viewModel = await makeViewModel(styles: styles)
        line(viewModel)
        viewModel.captions.saveCaptionStyle(named: "")
        let id = try #require(styles.captionStyles.styles.first?.id)
        #expect(styles.captionStyles.style(id)?.name == "My style")
        #expect(viewModel.captions.suggestedCaptionStyleName == "My style 2")
        viewModel.captions.renameCaptionStyle(id, to: "  Weekly  ")
        #expect(styles.captionStyles.style(id)?.name == "Weekly")
        let card = try #require(viewModel.captions.captionCardSections(.mine).first?.cards.first)
        viewModel.captions.duplicateCaptionStyle(card)
        #expect(styles.captionStyles.styles.map(\.name) == ["Weekly", "Weekly copy"])
        let comic = try #require(viewModel.captions.captionCardSections(.category(.impact)).first?.cards.first { $0.kind == .builtIn(.comic) })
        viewModel.captions.duplicateCaptionStyle(comic)
        #expect(styles.captionStyles.styles.last?.look.settings.theme == .comic)
        viewModel.captions.toggleFavoriteCaptionStyle(.builtIn("comic"))
        viewModel.captions.toggleFavoriteCaptionStyle(.saved(id))
        let favorites = viewModel.captions.captionCardSections(.favorites).flatMap(\.cards).map(\.name)
        #expect(favorites == ["Weekly", "Comic"])
    }

    @Test func newCaptionsStartInTheDefaultStyleOnlyWhileNeverStyled() async throws {
        let styles = FakeTextStyleStore()
        var mine = CaptionSettings(theme: .editorial)
        mine.sizeScale = 1.2
        let style = styles.captionStyles.add(MyCaptionStyle(settings: mine, animation: .line), named: "Serif big")
        styles.captionStyles.setDefault(style.key)
        let viewModel = await makeViewModel(styles: styles)
        var snapshot = EditSnapshot(viewModel.edit)
        viewModel.captions.startsCaptionsInDefaultStyle(&snapshot)
        #expect(snapshot.captionCollection?.theme == .editorial)
        #expect(snapshot.captionCollection?.sizeScale == 1.2, "a new video takes the style whole")

        viewModel.captions.pickCaptionTheme(.pop)
        var styled = EditSnapshot(viewModel.edit)
        viewModel.captions.startsCaptionsInDefaultStyle(&styled)
        #expect(styled.captionCollection?.theme == .pop)

        // One of Cue's styles can be the default too.
        styles.captionStyles.setDefault(.builtIn("band"))
        let fresh = await makeViewModel(styles: styles)
        var start = EditSnapshot(fresh.edit)
        fresh.captions.startsCaptionsInDefaultStyle(&start)
        #expect(start.captionCollection?.theme == .band)
    }

    @Test func theFilterIsKeptForTheNextVideo() async {
        let styles = FakeTextStyleStore()
        let first = await makeViewModel(styles: styles)
        first.captions.setCaptionCatalogFilter(.category(.editorial))
        let second = await makeViewModel(styles: styles)
        #expect(second.captions.captionCatalogFilter == .category(.editorial))
        #expect(second.captions.captionCardSections(.category(.editorial)).first?.cards.count == 4)
    }
}
