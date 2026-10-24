//
//  QuickEditTextStyleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Text style's explicit scope: only the picked text or every text, for the look only (the words,
/// timing and motion are the picked text's, and the captions are never touched); typing is one undo
/// step; the editorial preset on one title, then on all of them.
@MainActor
@Suite("Quick edit text style")
struct QuickEditTextStyleTests {
    private func makeViewModel() async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    /// A title and a subtitle, the title picked.
    private func twoTexts(_ viewModel: QuickEditViewModel) -> (title: UUID, subtitle: UUID) {
        viewModel.overlays.addStyledText(.subtitle)
        let subtitle = viewModel.edit.texts[0].id
        viewModel.overlays.addStyledText(.title)
        let title = viewModel.edit.texts[1].id
        #expect(viewModel.selectedTextID == title)
        return (title, subtitle)
    }

    @Test func aNewTextOpensTextStyleWithTheKeyboard() async {
        let viewModel = await makeViewModel()
        viewModel.overlays.addStyledText(.hook)
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.overlays.focusesTextField)
        #expect(viewModel.overlays.textStyleScope == .selected)
        #expect(viewModel.edit.texts[0].preset == .pop)
        #expect(viewModel.overlays.textStyleScopeLabel(.selected) == "This hook")
        #expect(viewModel.overlays.textFieldPlaceholder == "Type your hook")
    }

    @Test func thisTitleChangesOnlyThePickedText() async {
        let viewModel = await makeViewModel()
        let ids = twoTexts(viewModel)
        viewModel.overlays.restyleText(.font(.dmSerif))
        let title = viewModel.edit.texts.first { $0.id == ids.title }
        let subtitle = viewModel.edit.texts.first { $0.id == ids.subtitle }
        #expect(title?.font == .dmSerif)
        // DM Serif Display only has its regular weight.
        #expect(title?.weight == .regular)
        #expect(title?.customized.contains(.font) == true)
        #expect(subtitle?.font == .dmSans)
    }

    @Test func allTextsChangeTogether() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        viewModel.overlays.textStyleScope = .allTexts
        #expect(viewModel.overlays.textStyleScopeLabel(.allTexts) == "All texts · 2")
        #expect(viewModel.panelSubtitle(.textStyle) == "All 2 texts change together")
        viewModel.overlays.restyleText(.color(.yellow))
        #expect(viewModel.edit.texts.allSatisfy { $0.color == .yellow })
        let captions = viewModel.edit.captionCollection
        viewModel.overlays.restyleText(.shadow(.outline))
        #expect(viewModel.edit.texts.allSatisfy { $0.hasOutline })
        // The captions keep their own look.
        #expect(viewModel.edit.captionCollection == captions)
    }

    @Test func textStyleOffersOnlyThisTextAndAllTexts() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        #expect(OverlaysViewModel.textStyleScopes == [.selected, .allTexts])
        #expect(viewModel.overlays.textStyleScopeLabel(.selected) == "This title")
        #expect(viewModel.overlays.textStyleScopeLabel(.allTexts) == "All texts · 2")
    }

    @Test func noScopeChangesTheCaptions() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        let captions = viewModel.edit.captionCollection
        let look = viewModel.edit.captionLook
        for scope in OverlaysViewModel.textStyleScopes {
            viewModel.overlays.textStyleScope = scope
            viewModel.overlays.restyleText(.shadow(.outline))
            viewModel.overlays.restyleText(.font(.dmSerif))
            viewModel.overlays.pickTextPreset(.pop)
            viewModel.overlays.saveMyStyle()
            viewModel.overlays.pickTextPreset(nil)
        }
        #expect(viewModel.edit.captionCollection == captions)
        #expect(viewModel.edit.captionLook == look)
    }

    @Test func wordsTimingAndMotionStayWithThePickedTextUnderAllTexts() async {
        let viewModel = await makeViewModel()
        let ids = twoTexts(viewModel)
        viewModel.overlays.textStyleScope = .allTexts
        let subtitle = viewModel.edit.texts.first { $0.id == ids.subtitle }
        viewModel.overlays.setTextContent(ids.title, "Só o título")
        viewModel.nudgeLayerEdge(.end, by: 0.1)
        viewModel.player.seek(to: (viewModel.overlays.editedSpan(ofText: ids.title)?.start ?? 0) + 0.05)
        viewModel.overlays.toggleKeyframe()
        #expect(viewModel.edit.texts.first { $0.id == ids.subtitle } == subtitle)
        let title = viewModel.edit.texts.first { $0.id == ids.title }
        #expect(title?.text == "Só o título")
        #expect(title?.keyframes.count == 1)
    }

    @Test func motionSaysItIsThePickedTextsWhateverTheScope() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        viewModel.overlays.textStyleScope = .allTexts
        #expect(viewModel.overlays.textStyleTabChangesLook)
        #expect(viewModel.panelSubtitle(.textStyle) == "All 2 texts change together")
        viewModel.panelTab = .motion
        #expect(!viewModel.overlays.textStyleTabChangesLook)
        #expect(viewModel.panelSubtitle(.textStyle) == "Motion and timing change only this text")
    }

    @Test func aTabFromAnotherPanelShowsPresetsInBothTheTabsAndTheContent() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        viewModel.panelTab = .reveal
        #expect(viewModel.overlays.textStyleTab == .presets)
        #expect(viewModel.overlays.textStyleTabChangesLook)
        viewModel.panelTab = .font
        #expect(viewModel.overlays.textStyleTab == .font)
        viewModel.panelTab = .motion
        #expect(viewModel.captions.captionStyleTab == .presets)
    }

    @Test func theExpandedPanelIsKeptBetweenTheStylingPanels() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        #expect(!viewModel.stylePanelIsExpanded)
        viewModel.stylePanelIsExpanded = true
        viewModel.selection = nil
        viewModel.panel = .captionStyle
        #expect(viewModel.stylePanelIsExpanded)
        #expect(EditorPanel.captionStyle.isExpandable && EditorPanel.textStyle.isExpandable)
        #expect(!EditorPanel.captions.isExpandable && !EditorPanel.background.isExpandable)
    }

    @Test func editorialOnTheTitleThenOnEveryText() async {
        let viewModel = await makeViewModel()
        let ids = twoTexts(viewModel)
        viewModel.overlays.pickTextPreset(.editorial)
        #expect(viewModel.edit.texts.first { $0.id == ids.title }?.preset == .editorial)
        #expect(viewModel.edit.texts.first { $0.id == ids.subtitle }?.preset == .minimal)
        #expect(viewModel.overlays.pickedTextPreset == .editorial)
        viewModel.overlays.textStyleScope = .allTexts
        viewModel.overlays.pickTextPreset(.editorial)
        #expect(viewModel.edit.texts.allSatisfy { $0.preset == .editorial && $0.font == .dmSerif })
    }

    @Test func typingIsOneUndoStep() async {
        let viewModel = await makeViewModel()
        viewModel.overlays.addStyledText(.title)
        let id = viewModel.edit.texts[0].id
        let steps = viewModel.document.history.past.count
        for text in ["5", "5 c", "5 co", "5 comidas de SP"] { viewModel.overlays.setTextContent(id, text) }
        #expect(viewModel.edit.texts[0].text == "5 comidas de SP")
        #expect(viewModel.document.history.past.count == steps + 1)
        viewModel.undo()
        #expect(viewModel.edit.texts[0].text == TextOverlayRole.title.placeholder)
    }

    @Test func aTextsStartAndEndMoveByTenths() async {
        let viewModel = await makeViewModel()
        viewModel.overlays.addStyledText(.title)
        let id = viewModel.edit.texts[0].id
        let before = viewModel.overlays.editedSpan(ofText: id)
        viewModel.nudgeLayerEdge(.end, by: 0.1)
        viewModel.nudgeLayerEdge(.start, by: 0.1)
        let after = viewModel.overlays.editedSpan(ofText: id)
        #expect(abs((after?.end ?? 0) - ((before?.end ?? 0) + 0.1)) < 0.001)
        #expect(abs((after?.start ?? 0) - ((before?.start ?? 0) + 0.1)) < 0.001)
    }

    @Test func keyframesAreCountedForThePickedText() async {
        let viewModel = await makeViewModel()
        viewModel.overlays.addStyledText(.title)
        #expect(viewModel.overlays.keyframeCountLabel == "No keyframes yet")
        #expect(!viewModel.overlays.hasKeyframeAtPlayhead)
        viewModel.overlays.toggleKeyframe()
        #expect(viewModel.overlays.keyframeCountLabel == "1 keyframe")
        #expect(viewModel.overlays.hasKeyframeAtPlayhead)
    }
}
