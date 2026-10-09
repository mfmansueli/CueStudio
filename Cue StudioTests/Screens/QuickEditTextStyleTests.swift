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
        viewModel.addStyledText(.subtitle)
        let subtitle = viewModel.edit.texts[0].id
        viewModel.addStyledText(.title)
        let title = viewModel.edit.texts[1].id
        #expect(viewModel.selectedTextID == title)
        return (title, subtitle)
    }

    @Test func aNewTextOpensTextStyleWithTheKeyboard() async {
        let viewModel = await makeViewModel()
        viewModel.addStyledText(.hook)
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.focusesTextField)
        #expect(viewModel.textStyleScope == .selected)
        #expect(viewModel.edit.texts[0].preset == .pop)
        #expect(viewModel.textStyleScopeLabel(.selected) == "This hook")
        #expect(viewModel.textFieldPlaceholder == "Type your hook")
    }

    @Test func thisTitleChangesOnlyThePickedText() async {
        let viewModel = await makeViewModel()
        let ids = twoTexts(viewModel)
        viewModel.restyleText(.font(.dmSerif))
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
        viewModel.textStyleScope = .allTexts
        #expect(viewModel.textStyleScopeLabel(.allTexts) == "All texts · 2")
        #expect(viewModel.panelSubtitle(.textStyle) == "All 2 texts change together")
        viewModel.restyleText(.color(.yellow))
        #expect(viewModel.edit.texts.allSatisfy { $0.color == .yellow })
        let captions = viewModel.edit.captionCollection
        viewModel.restyleText(.shadow(.outline))
        #expect(viewModel.edit.texts.allSatisfy { $0.hasOutline })
        // The captions keep their own look.
        #expect(viewModel.edit.captionCollection == captions)
    }

    @Test func textStyleOffersOnlyThisTextAndAllTexts() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        #expect(QuickEditViewModel.textStyleScopes == [.selected, .allTexts])
        #expect(viewModel.textStyleScopeLabel(.selected) == "This title")
        #expect(viewModel.textStyleScopeLabel(.allTexts) == "All texts · 2")
    }

    @Test func noScopeChangesTheCaptions() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        let captions = viewModel.edit.captionCollection
        let look = viewModel.edit.captionLook
        for scope in QuickEditViewModel.textStyleScopes {
            viewModel.textStyleScope = scope
            viewModel.restyleText(.shadow(.outline))
            viewModel.restyleText(.font(.dmSerif))
            viewModel.pickTextPreset(.pop)
            viewModel.saveMyStyle()
            viewModel.pickTextPreset(nil)
        }
        #expect(viewModel.edit.captionCollection == captions)
        #expect(viewModel.edit.captionLook == look)
    }

    @Test func wordsTimingAndMotionStayWithThePickedTextUnderAllTexts() async {
        let viewModel = await makeViewModel()
        let ids = twoTexts(viewModel)
        viewModel.textStyleScope = .allTexts
        let subtitle = viewModel.edit.texts.first { $0.id == ids.subtitle }
        viewModel.setTextContent(ids.title, "Só o título")
        viewModel.nudgeLayerEdge(.end, by: 0.1)
        viewModel.player.seek(to: (viewModel.editedSpan(ofText: ids.title)?.start ?? 0) + 0.05)
        viewModel.toggleKeyframe()
        #expect(viewModel.edit.texts.first { $0.id == ids.subtitle } == subtitle)
        let title = viewModel.edit.texts.first { $0.id == ids.title }
        #expect(title?.text == "Só o título")
        #expect(title?.keyframes.count == 1)
    }

    @Test func motionSaysItIsThePickedTextsWhateverTheScope() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        viewModel.textStyleScope = .allTexts
        #expect(viewModel.textStyleTabChangesLook)
        #expect(viewModel.panelSubtitle(.textStyle) == "All 2 texts change together")
        viewModel.panelTab = .motion
        #expect(!viewModel.textStyleTabChangesLook)
        #expect(viewModel.panelSubtitle(.textStyle) == "Motion and timing change only this text")
    }

    @Test func aTabFromAnotherPanelShowsPresetsInBothTheTabsAndTheContent() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        viewModel.panelTab = .reveal
        #expect(viewModel.textStyleTab == .presets)
        #expect(viewModel.textStyleTabChangesLook)
        viewModel.panelTab = .font
        #expect(viewModel.textStyleTab == .font)
        viewModel.panelTab = .frame
        #expect(viewModel.captionStyleTab == .presets)
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
        #expect(!EditorPanel.captions.isExpandable && !EditorPanel.cover.isExpandable)
    }

    @Test func editorialOnTheTitleThenOnEveryText() async {
        let viewModel = await makeViewModel()
        let ids = twoTexts(viewModel)
        viewModel.pickTextPreset(.editorial)
        #expect(viewModel.edit.texts.first { $0.id == ids.title }?.preset == .editorial)
        #expect(viewModel.edit.texts.first { $0.id == ids.subtitle }?.preset == .minimal)
        #expect(viewModel.pickedTextPreset == .editorial)
        viewModel.textStyleScope = .allTexts
        viewModel.pickTextPreset(.editorial)
        #expect(viewModel.edit.texts.allSatisfy { $0.preset == .editorial && $0.font == .dmSerif })
    }

    @Test func typingIsOneUndoStep() async {
        let viewModel = await makeViewModel()
        viewModel.addStyledText(.title)
        let id = viewModel.edit.texts[0].id
        let steps = viewModel.history.past.count
        for text in ["5", "5 c", "5 co", "5 comidas de SP"] { viewModel.setTextContent(id, text) }
        #expect(viewModel.edit.texts[0].text == "5 comidas de SP")
        #expect(viewModel.history.past.count == steps + 1)
        viewModel.undo()
        #expect(viewModel.edit.texts[0].text == TextOverlayRole.title.placeholder)
    }

    @Test func aTextsStartAndEndMoveByTenths() async {
        let viewModel = await makeViewModel()
        viewModel.addStyledText(.title)
        let id = viewModel.edit.texts[0].id
        let before = viewModel.editedSpan(ofText: id)
        viewModel.nudgeLayerEdge(.end, by: 0.1)
        viewModel.nudgeLayerEdge(.start, by: 0.1)
        let after = viewModel.editedSpan(ofText: id)
        #expect(abs((after?.end ?? 0) - ((before?.end ?? 0) + 0.1)) < 0.001)
        #expect(abs((after?.start ?? 0) - ((before?.start ?? 0) + 0.1)) < 0.001)
    }

    @Test func keyframesAreCountedForThePickedText() async {
        let viewModel = await makeViewModel()
        viewModel.addStyledText(.title)
        #expect(viewModel.keyframeCountLabel == "No keyframes yet")
        #expect(!viewModel.hasKeyframeAtPlayhead)
        viewModel.toggleKeyframe()
        #expect(viewModel.keyframeCountLabel == "1 keyframe")
        #expect(viewModel.hasKeyframeAtPlayhead)
    }
}
