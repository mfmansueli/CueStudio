//
//  QuickEditTextStyleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Text style's explicit scope: only the picked text, every text, or every text and the captions;
/// typing is one undo step; the editorial preset on one title, then on all of them.
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

    @Test func plusCaptionsChangesTheCaptionsToo() async {
        let viewModel = await makeViewModel()
        _ = twoTexts(viewModel)
        viewModel.textStyleScope = .textsAndCaptions
        viewModel.restyleText(.shadow(.outline))
        #expect(viewModel.edit.texts.allSatisfy { $0.hasOutline })
        #expect(viewModel.edit.captionCollection == nil)
        #expect(viewModel.edit.captionLook?.hasOutline == true)
        // Size only changes texts: the captions keep a size a line of five words fits in.
        let captionScale = viewModel.edit.captionLook?.sizeScale
        viewModel.restyleText(.size(40))
        #expect(viewModel.edit.texts.allSatisfy { abs($0.size - 40 * TextOverlayRole.designScale) < 0.001 })
        #expect(viewModel.edit.captionLook?.sizeScale == captionScale)
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
