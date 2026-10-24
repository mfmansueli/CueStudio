//
//  QuickEditBackgroundPanelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the reorganized Background panel says: its subtitle (scope and what is behind the creator), the note with its scope's rule, and
/// when its folded green screen settings were changed. Every value stays while another background or cutout is picked.
@MainActor
@Suite("Quick edit background panel")
struct QuickEditBackgroundPanelTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 21.6
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 21.6
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player)
    }

    /// Two clips: 0–7.1 and 7.1–21.6.
    private func split(_ scenario: Scenario) {
        scenario.player.seek(to: 7.1)
        scenario.viewModel.clips.selectClipAtPlayhead()
        scenario.viewModel.clips.splitClip()
        scenario.viewModel.selection = nil
    }

    private func openFromClip(_ viewModel: QuickEditViewModel, _ index: Int) {
        viewModel.panel = nil
        viewModel.selection = .clip(viewModel.edit.timeline.segments[index].id)
        viewModel.perform(.open(.background))
    }

    @Test(arguments: [
        (BackgroundStyle.original, BackgroundCutout.person, "As recorded"),
        (.original, .colorKey, "As recorded"),
        (.blur, .person, "Blur behind you"),
        (.color, .person, "Color behind you"),
        (.image, .person, "Image behind you"),
        (.blur, .colorKey, "Blur on the green or blue screen"),
        (.color, .colorKey, "Color on the green or blue screen"),
        (.image, .colorKey, "Image on the green or blue screen"),
    ])
    func theSummarySaysWhatIsBehindTheCreator(style: BackgroundStyle, cutout: BackgroundCutout, expected: String) {
        var effect = BackgroundEffect()
        effect.style = style
        effect.cutout = cutout
        effect.imageFileName = "beach.jpg"
        #expect(LookViewModel.backgroundSummary(of: effect) == expected)
    }

    @Test func anImageWithoutItsPhotoAsksForOne() {
        var effect = BackgroundEffect()
        effect.style = .image
        #expect(LookViewModel.backgroundSummary(of: effect) == "No photo chosen yet")
    }

    @Test func theSubtitleSaysTheScopeAndTheBackground() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.background))
        #expect(viewModel.panelSubtitle(.background) == "Whole video · As recorded")
        viewModel.look.setBackgroundStyle(.blur)
        #expect(viewModel.panelSubtitle(.background) == "Whole video · Blur behind you")
        openFromClip(viewModel, 1)
        #expect(viewModel.panelSubtitle(.background) == "Clip 2 of 2 · Blur behind you")
        viewModel.look.setBackgroundCutout(.colorKey)
        #expect(viewModel.panelSubtitle(.background) == "Clip 2 of 2 · Blur on the green or blue screen")
    }

    @Test func theScopeNoteTellsTheRuleOnlyWhenThereIsOne() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.background))
        #expect(viewModel.look.backgroundScopeNote == nil)
        viewModel.look.setBackgroundStyle(.blur)
        openFromClip(viewModel, 1)
        #expect(viewModel.look.backgroundScopeNote == "Shows the whole video's background. A change here is for this clip only.")
        viewModel.look.setBackgroundStyle(.color)
        #expect(viewModel.look.clipOverridesBackground)
        #expect(viewModel.look.backgroundScopeNote == "This clip has its own background. Reset gives it the whole video's again.")
        viewModel.panel = nil
        viewModel.selection = nil
        viewModel.perform(.open(.background))
        #expect(viewModel.look.backgroundScopeNote == "Clips with their own background keep it.")
        // Reset gives the clip the take's again, and the note goes with it.
        openFromClip(viewModel, 1)
        viewModel.look.resetClipBackground()
        #expect(viewModel.look.backgroundScopeNote == "Shows the whole video's background. A change here is for this clip only.")
    }

    @Test func theFoldedSettingsSayWhenTheyWereChanged() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundCutout(.colorKey)
        viewModel.look.setKeyColor(red: ChromaKey.blue.red, green: ChromaKey.blue.green, blue: ChromaKey.blue.blue)
        #expect(!viewModel.look.backgroundKeyIsAdjusted, "the screen's color is shown, not folded")
        viewModel.look.updateBackground { $0.key.spill = 0.8 }
        #expect(viewModel.look.backgroundKeyIsAdjusted)
        viewModel.undo()
        #expect(!viewModel.look.backgroundKeyIsAdjusted)
    }

    @Test func everyValueStaysWhileAnotherBackgroundOrCutoutIsPicked() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.blur)
        viewModel.look.updateBackground { $0.blur = 0.8 }
        viewModel.look.setBackgroundStyle(.color)
        viewModel.look.updateBackground { $0.color = .blue }
        viewModel.look.setBackgroundCutout(.colorKey)
        viewModel.look.setKeyColor(red: ChromaKey.blue.red, green: ChromaKey.blue.green, blue: ChromaKey.blue.blue)
        viewModel.look.updateBackground { $0.key.tolerance = 0.6 }
        viewModel.look.setBackgroundCutout(.person)
        viewModel.look.setBackgroundStyle(.original)
        viewModel.look.setBackgroundStyle(.blur)
        viewModel.look.setBackgroundCutout(.colorKey)
        let effect = viewModel.look.currentBackground
        #expect(effect.blur == 0.8)
        #expect(effect.color == .blue)
        #expect(effect.key.tolerance == 0.6)
        #expect(abs(effect.key.blue - ChromaKey.blue.blue) < 0.001)
    }

    @Test func pickingTheCutoutIsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.color)
        viewModel.look.setBackgroundCutout(.colorKey)
        #expect(viewModel.edit.background(for: nil)?.cutout == .colorKey)
        viewModel.undo()
        #expect(viewModel.edit.background(for: nil)?.cutout == .person)
        #expect(viewModel.edit.background(for: nil)?.style == .color)
        viewModel.redo()
        #expect(viewModel.edit.background(for: nil)?.cutout == .colorKey)
    }

    @Test func thePanelKeepsTheTimelineAndClearsTheHomeIndicator() {
        // Medium: the ruler and the video track stay (Background follows the clip and the recording under the playhead).
        #expect(EditorPanel.background.size == .medium)
        #expect(!EditorPanel.background.isExpandable)
        #expect(EditorPanel.background.scrollsClearOfHomeIndicator)
        #expect(EditorPanel.textStyle.scrollsClearOfHomeIndicator && !EditorPanel.adjust.scrollsClearOfHomeIndicator)
    }
}
