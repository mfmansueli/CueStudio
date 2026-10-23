//
//  QuickEditCaptionStyleCopyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Text style › "Apply this style to captions" in the editor: it asks first, copies the picked
/// text's look onto the captions once (nothing else changes, no other text, no link afterwards), is
/// one undo step, survives a draft and Done, and Caption style shows the result as Custom until a
/// preset replaces it, on the captions only.
@MainActor
@Suite("Quick edit · apply a text's style to captions")
struct QuickEditCaptionStyleCopyTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let takes: TakeLibraryService
        let drafts: FakeDraftStore
        let toast: ToastService
    }

    private func makeScenario(drafts: FakeDraftStore = FakeDraftStore(), takes: TakeLibraryService? = nil, captions: Bool = true) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = takes ?? {
            let service = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
            service.load()
            return service
        }()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: drafts, toast: toast, player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        if captions, viewModel.edit.captions.isEmpty {
            viewModel.changeEdit {
                $0.captions = [CaptionCue(text: "Comidas de SP", start: 0.3, end: 2.3), CaptionCue(text: "que são só pra turista.", start: 2.3, end: 4)]
                $0.showsCaptions = true
            }
        }
        return Scenario(viewModel: viewModel, takes: takes, drafts: drafts, toast: toast)
    }

    /// A subtitle, then a title restyled by hand (serif, yellow, on a pill), picked.
    private func styledTexts(_ viewModel: QuickEditViewModel) -> (title: UUID, subtitle: UUID) {
        viewModel.addStyledText(.subtitle)
        let subtitle = viewModel.edit.texts[0].id
        viewModel.addStyledText(.title)
        let title = viewModel.edit.texts[1].id
        viewModel.setTextContent(title, "5 comidas de SP")
        viewModel.restyleText(.font(.dmSerif))
        viewModel.restyleText(.color(.lavender))
        viewModel.restyleText(.background(.pill))
        viewModel.restyleText(.backgroundColor(.black))
        viewModel.restyleText(.glow(0.4))
        viewModel.restyleText(.size(80))
        return (title, subtitle)
    }

    private func text(_ id: UUID, in viewModel: QuickEditViewModel) -> TextOverlay? {
        viewModel.edit.texts.first { $0.id == id }
    }

    // MARK: - Asking

    @Test func theActionShowsOnlyForAPickedTextWithCaptions() async {
        let withCaptions = await makeScenario()
        #expect(!withCaptions.viewModel.captions.canCopyStyleToCaptions)
        _ = styledTexts(withCaptions.viewModel)
        #expect(withCaptions.viewModel.captions.canCopyStyleToCaptions)
        let without = await makeScenario(captions: false)
        _ = styledTexts(without.viewModel)
        #expect(!without.viewModel.captions.canCopyStyleToCaptions)
        without.viewModel.captions.askToCopyStyleToCaptions()
        #expect(without.viewModel.captions.captionStyleCopySourceID == nil)
    }

    @Test func askingSaysWhatIsReplacedAndWhatStays() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let ids = styledTexts(viewModel)
        viewModel.captions.askToCopyStyleToCaptions()
        #expect(viewModel.captions.captionStyleCopySourceID == ids.title)
        let message = viewModel.captions.captionStyleCopyMessage
        #expect(message.contains("Your captions use the Cue preset."))
        #expect(message.contains("Words, timing, translations, position, size and how lines appear stay the same. Other texts don’t change."))
        #expect(!message.contains("highlight color changes"))
    }

    @Test func cancelChangesNothing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        let edit = viewModel.edit
        let steps = viewModel.document.history.past.count
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.cancelCopyingStyleToCaptions()
        #expect(viewModel.captions.captionStyleCopySourceID == nil)
        #expect(viewModel.edit == edit)
        #expect(viewModel.document.history.past.count == steps)
    }

    // MARK: - Applying

    @Test func applyCopiesTheLookOnceAndKeepsEverythingElse() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let ids = styledTexts(viewModel)
        // The captions moved up, made bigger, with words appearing as they're said.
        viewModel.captions.moveCaptions(toY: 0.3)
        viewModel.captions.setCaptionPointSize(22)
        viewModel.captions.pickCaptionReveal(.groups)
        let before = viewModel.edit
        let reveal = viewModel.captions.captionReveal
        let steps = viewModel.document.history.past.count

        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()

        let title = text(ids.title, in: viewModel)
        let look = viewModel.edit.captionCollection?.customLook
        #expect(look?.font == .dmSerif && look?.color == .lavender && look?.background == .pill && look?.glow == 0.4)
        // The captions' own size, not the title's 80 pt.
        #expect(viewModel.captions.captionPointSize == 22)
        #expect(viewModel.edit.captionCollection?.center == before.captionCollection?.center)
        #expect(viewModel.edit.captionCollection?.theme == before.captionCollection?.theme)
        #expect(viewModel.captions.captionReveal == reveal)
        #expect(viewModel.edit.captions == before.captions)
        #expect(viewModel.edit.captionTranslations == before.captionTranslations)
        #expect(viewModel.edit.captionDisplay == before.captionDisplay)
        #expect(viewModel.edit.showsCaptions == before.showsCaptions)
        #expect(viewModel.edit.captionPosition == before.captionPosition)
        // No text changed, the source included.
        #expect(viewModel.edit.texts == before.texts)
        #expect(title?.size == 80)
        // One undo step; the question is answered.
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.captions.captionStyleCopySourceID == nil)
        #expect(scenario.toast.message == "Captions use this style")
        #expect(scenario.toast.action?.title == "Undo")
    }

    @Test func undoAndRedoTakeTheCopyBackAndForth() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        let before = viewModel.edit
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()
        let after = viewModel.edit
        viewModel.undo()
        #expect(viewModel.edit == before)
        #expect(viewModel.captions.captionTheme == .cue)
        viewModel.redo()
        #expect(viewModel.edit == after)
        #expect(viewModel.captions.captionTheme == nil)
        // The toast's Undo is the same step.
        scenario.toast.action?.perform()
        #expect(viewModel.edit == before)
    }

    @Test func theTextAndTheCaptionsArentLinkedAfterwards() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let ids = styledTexts(viewModel)
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()
        let copied = viewModel.edit.captionCollection
        viewModel.restyleText(.color(.mint))
        viewModel.textStyleScope = .allTexts
        viewModel.pickTextPreset(.pop)
        #expect(viewModel.edit.captionCollection == copied)
        #expect(text(ids.title, in: viewModel)?.color != copied?.customLook?.color)
    }

    @Test func aHighlightThatWouldVanishIsMovedAndSaid() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        viewModel.restyleText(.background(.none))
        viewModel.restyleText(.color(.yellow))
        viewModel.captions.askToCopyStyleToCaptions()
        #expect(viewModel.captions.captionStyleCopyMessage.contains("The highlight color changes so the word being said stands out: White."))
        viewModel.captions.copyStyleToCaptions()
        #expect(viewModel.captions.captionAccent == .white)
    }

    @Test func allTextsStillCopiesOnlyThePickedTextsLook() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let ids = styledTexts(viewModel)
        viewModel.textStyleScope = .allTexts
        let subtitle = text(ids.subtitle, in: viewModel)
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()
        #expect(viewModel.edit.captionCollection?.customLook?.font == .dmSerif)
        #expect(text(ids.subtitle, in: viewModel) == subtitle)
    }

    // MARK: - Caption style afterwards

    @Test func captionStyleShowsCustomAndItsFontEditsIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()
        viewModel.selection = nil
        viewModel.panel = .captionStyle
        #expect(viewModel.captions.captionTheme == nil)
        #expect(viewModel.captions.captionCustomLook?.font == .dmSerif)
        #expect(viewModel.captions.captionCustomLookName == "Custom")
        #expect(viewModel.captions.captionEditableLook?.font == .dmSerif)
        viewModel.captions.updateCaptionLook { $0.color = .cyan }
        #expect(viewModel.edit.captionCollection?.customLook?.color == .cyan)
        // The highlight stays the collection's to pick.
        viewModel.captions.setCaptionAccent(.peach)
        #expect(viewModel.captions.captionAccent == .peach)
    }

    @Test func aPresetAfterwardsReplacesTheCopyOnTheCaptionsOnly() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()
        let texts = viewModel.edit.texts
        let textLook = viewModel.edit.textLook
        viewModel.captions.moveCaptions(toY: 0.3)
        viewModel.panel = .captionStyle
        viewModel.captions.pickCaptionTheme(.cue)
        #expect(viewModel.captions.captionTheme == .cue)
        #expect(viewModel.captions.captionCustomLook == nil)
        #expect(viewModel.edit.captionCollection?.center?.y == 0.3)
        #expect(viewModel.edit.texts == texts)
        #expect(viewModel.edit.textLook == textLook)
        // One step back is the copied look again.
        viewModel.undo()
        #expect(viewModel.captions.captionCustomLook?.font == .dmSerif)
    }

    @Test func captionsFromBeforeTheCollectionTakeTheLookAsTheirs() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        var old = TypePreset.soft.look(for: .caption)
        old.sizeScale = 1.2
        viewModel.changeEdit {
            $0.captionCollection = nil
            $0.captionLook = old
            $0.captionPreset = .soft
            $0.captionAnimation = .fade
        }
        viewModel.captions.askToCopyStyleToCaptions()
        #expect(viewModel.captions.captionStyleCopyMessage.contains("Your captions use the \(TypePreset.soft.label) preset."))
        viewModel.captions.copyStyleToCaptions()
        #expect(viewModel.edit.captionCollection == nil)
        #expect(viewModel.edit.captionLook?.font == .dmSerif)
        #expect(viewModel.edit.captionLook?.sizeScale == 1.2)
        #expect(viewModel.edit.captionPreset == nil)
        #expect(viewModel.edit.captionAnimation == .fade)
        #expect(viewModel.captions.captionCustomLookName == "Custom")
    }

    // MARK: - Kept

    @Test func theCopyStaysInTheDraftAndUndoWorksAfterReopening() async {
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts)
        _ = styledTexts(first.viewModel)
        let before = first.viewModel.edit.captionCollection
        first.viewModel.captions.askToCopyStyleToCaptions()
        first.viewModel.captions.copyStyleToCaptions()
        let copied = first.viewModel.edit.captionCollection
        first.viewModel.cancel()
        #expect(drafts.drafts.count == 1)

        let second = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(second.viewModel.edit.captionCollection == copied)
        #expect(second.viewModel.captions.captionTheme == nil)
        second.viewModel.undo()
        #expect(second.viewModel.edit.captionCollection == before)
    }

    @Test func doneSavesTheCopyOnTheTake() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        _ = styledTexts(viewModel)
        viewModel.captions.askToCopyStyleToCaptions()
        viewModel.captions.copyStyleToCaptions()
        let copied = viewModel.edit.captionCollection
        viewModel.done()
        let saved = scenario.takes.takes[0].edit?.captionCollection
        #expect(saved?.customLook == copied?.customLook)
        #expect(saved?.customLook?.font == .dmSerif)
        #expect(saved?.theme == copied?.theme && saved?.sizeScale == copied?.sizeScale)
    }
}
