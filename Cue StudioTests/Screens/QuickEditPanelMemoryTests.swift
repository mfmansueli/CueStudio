//
//  QuickEditPanelMemoryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Canvas 2 delivery 3 (owner, 07/11/2026): R7, a panel opens on the tab and Advanced it was left with in this video, per item
/// where its controls are an item's; R11, Text to speech and a brand kit keep what was typed when closed by a swipe, and Cancel
/// throws it away.
@MainActor
@Suite("Quick edit · panels and sheets keep where they were left")
struct QuickEditPanelMemoryTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
    }

    /// Two clips: 0–10 and 10–20.
    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        player.seek(to: 10)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        viewModel.selection = nil
        return Scenario(viewModel: viewModel, player: player)
    }

    private func clip(_ index: Int, of viewModel: QuickEditViewModel) -> EditorSelection {
        .clip(viewModel.edit.timeline.segments[index].id)
    }

    // MARK: - R7

    @Test func aWholeVideoPanelOpensOnTheTabItWasLeftOn() async {
        let viewModel = await makeScenario().viewModel
        viewModel.panel = .captionStyle
        viewModel.panelTab = .layout
        viewModel.panel = nil
        viewModel.panel = .adjust
        #expect(viewModel.panelTab == .presets, "Another panel took Caption style's tab")
        viewModel.panel = .captionStyle
        #expect(viewModel.panelTab == .layout)
    }

    @Test func aClipsAdvancedIsRememberedForThatClip() async {
        let viewModel = await makeScenario().viewModel
        viewModel.selection = clip(0, of: viewModel)
        viewModel.panel = .volume
        viewModel.showsAdvanced = true
        // Another clip picked with Volume open: as Volume starts for it.
        viewModel.selection = clip(1, of: viewModel)
        #expect(viewModel.panel == .volume)
        #expect(!viewModel.showsAdvanced)
        viewModel.selection = clip(0, of: viewModel)
        #expect(viewModel.showsAdvanced, "The first clip's Advanced wasn't kept")
        // Closed and opened again on it: still open.
        viewModel.panel = nil
        viewModel.panel = .volume
        #expect(viewModel.showsAdvanced)
    }

    @Test func aPathThatAsksForATabStillGetsIt() async {
        let viewModel = await makeScenario().viewModel
        viewModel.panel = .captionStyle
        viewModel.panelTab = .layout
        viewModel.panel = nil
        viewModel.panel = .captionStyle
        viewModel.panelTab = .animation
        #expect(viewModel.panelTab == .animation)
    }

    @Test func theMemoryKeepsOnlyWhatDiffersFromHowAPanelStarts() {
        var memory = PanelMemory()
        let item = UUID()
        memory.remember(PanelMemory.State(tab: .styles, showsAdvanced: true), of: .volume, item: item)
        #expect(memory.state(of: .volume, item: item).showsAdvanced)
        #expect(!memory.state(of: .volume, item: UUID()).showsAdvanced)
        // A whole video's panel ignores the item.
        memory.remember(PanelMemory.State(tab: .layout), of: .captionStyle, item: item)
        #expect(memory.state(of: .captionStyle, item: nil).tab == .layout)
        memory.remember(PanelMemory.State(), of: .volume, item: item)
        #expect(memory == {
            var other = PanelMemory()
            other.remember(PanelMemory.State(tab: .layout), of: .captionStyle, item: nil)
            return other
        }())
    }

    // MARK: - R11

    @Test func textToSpeechComesBackWhereItWasWritten() async {
        let viewModel = await makeScenario().viewModel
        let speech = viewModel.audio.makeTextToSpeech()
        let start = speech.draft
        speech.text = "Three habits that changed my mornings."
        speech.speed = 1.25
        viewModel.audio.keepTextToSpeechDraft(speech.draft, opened: start, wasDraft: false)
        let again = viewModel.audio.makeTextToSpeech()
        #expect(again.text == "Three habits that changed my mornings." && again.speed == 1.25 && again.isRestoredDraft)
        // Closed again without touching it: still kept.
        viewModel.audio.keepTextToSpeechDraft(again.draft, opened: start, wasDraft: true)
        #expect(viewModel.audio.textToSpeechDraft?.text == "Three habits that changed my mornings.")
        // Opened to edit another voice-over's words: not there.
        viewModel.audio.textToSpeechDraft?.replacingID = UUID()
        #expect(viewModel.audio.makeTextToSpeech().text.isEmpty)
    }

    @Test func anUntouchedTextToSpeechLeavesNothing() async {
        let viewModel = await makeScenario().viewModel
        let speech = viewModel.audio.makeTextToSpeech()
        viewModel.audio.keepTextToSpeechDraft(speech.draft, opened: speech.draft, wasDraft: false)
        #expect(viewModel.audio.textToSpeechDraft == nil)
    }

    @Test func aBrandKitClosedBySwipeComesBackAndCancelEndsIt() async {
        let viewModel = await makeScenario().viewModel
        let brand = viewModel.brand
        let start = brand.kitFromThisVideo()
        brand.edit(start)
        var changed = start
        changed.name = "Morning show"
        brand.sheetClosed(on: changed, openedWith: start)
        #expect(brand.kitBeingEdited == nil)
        // A new kit started again: the draft comes back.
        brand.edit(brand.kitFromThisVideo())
        #expect(brand.kitBeingEdited?.name == "Morning show" && brand.kitBeingEditedIsDraft)
        brand.discardKitChanges()
        brand.edit(brand.kitFromThisVideo())
        #expect(brand.kitBeingEdited?.name != "Morning show" && !brand.kitBeingEditedIsDraft)
    }
}
