//
//  QuickEditToolbarTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Quick edit toolbar")
struct QuickEditToolbarTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario(duration: TimeInterval = 21.6) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = duration
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = duration
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func ids(_ viewModel: QuickEditViewModel) -> [String] {
        viewModel.toolbarItems.map(\.id)
    }

    // MARK: - Contexts

    @Test func theMainToolbarHasEveryToolWithNothingPicked() async {
        let viewModel = await makeScenario().viewModel
        #expect(ids(viewModel) == ["edit", "text", "captions", "audio", "pauses", "media", "adjust", "filters", "background", "crop"])
        #expect(viewModel.toolbarContextLabel == nil)
    }

    @Test func editPicksTheClipUnderThePlayheadAndShowsItsTools() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.selection == .clip(viewModel.edit.timeline.segments[0].id))
        #expect(viewModel.toolbarContextLabel == "Clip")
        #expect(ids(viewModel) == ["split", "speed", "adjust", "filters", "background", "zoom", "volume", "voice", "duplicate", "delete"])
        #expect(viewModel.toolbarItems.last?.style == .destructive)
    }

    @Test func speedAndZoomStaySeparateTools() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.toolbarItems.first { $0.id == "speed" }?.action == .open(.speed))
        #expect(viewModel.toolbarItems.first { $0.id == "zoom" }?.action == .open(.zoom))
    }

    @Test func eachPickedItemHasItsOwnTools() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        #expect(viewModel.toolbarContextLabel == "Text")
        #expect(ids(viewModel) == ["editText", "style", "keyframe", "duplicate", "delete"])
        let line = CaptionCue(text: "Massa fina, muito recheio", start: 12.4, end: 14.6, origin: .manual)
        viewModel.edit.captions = [line]
        viewModel.selection = .caption(line.id)
        #expect(viewModel.toolbarContextLabel == "Caption")
        #expect(ids(viewModel) == ["editCaption", "split", "join", "style", "delete"])
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        viewModel.edit.music = [music]
        viewModel.selection = .music(music.id)
        #expect(ids(viewModel) == ["volume", "replace", "delete"])
        let voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)
        viewModel.edit.voiceOvers = [voice]
        viewModel.selection = .voiceOver(voice.id)
        #expect(ids(viewModel) == ["volume", "reRecord", "delete"])
    }

    @Test func textAndAudioMenus() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMenu(.text))
        #expect(viewModel.toolbarContextLabel == "Text")
        #expect(ids(viewModel) == ["title", "subtitle", "hook", "callout"])
        viewModel.perform(.addText(.hook))
        viewModel.leaveToolbarContext()
        viewModel.perform(.openMenu(.text))
        #expect(ids(viewModel).last == "styleAll")
        viewModel.perform(.openMenu(.audio))
        #expect(ids(viewModel) == ["voice", "music", "voiceOver"])
        viewModel.leaveToolbarContext()
        #expect(viewModel.toolbarContextLabel == nil)
        #expect(viewModel.toolMenu == nil)
    }

    @Test func addingATextOpensTextStyleWithTheKeyboard() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMenu(.text))
        viewModel.perform(.addText(.title))
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.focusesTextField)
        #expect(viewModel.textStyleScope == .selected)
        #expect(viewModel.editingTextID == nil)
        #expect(viewModel.panelSubtitle(.textStyle) == "Only this title changes")
    }

    @Test func styleAllOpensTextStyleForEveryText() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        viewModel.perform(.addText(.hook))
        viewModel.leaveToolbarContext()
        viewModel.perform(.styleAllTexts)
        #expect(viewModel.textStyleScope == .allTexts)
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.panelSubtitle(.textStyle) == "All 2 texts change together")
    }

    @Test func captionsOpenAutoCaptionsUntilThereAreLines() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openCaptions)
        #expect(viewModel.panel == .autoCaptions)
        viewModel.edit.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)]
        viewModel.perform(.openCaptions)
        #expect(viewModel.panel == .captions)
    }

    @Test func musicAlwaysOpensFilesToAddAClipAtThePlayhead() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMusic)
        #expect(viewModel.sheet == .music)
        #expect(viewModel.musicReplacementID == nil)
        viewModel.sheet = nil
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        viewModel.edit.music = [music]
        viewModel.perform(.openMusic)
        #expect(viewModel.sheet == .music)
        #expect(viewModel.selection == nil)
    }

    @Test func replaceAsksForAFileForThePickedClipOnly() async {
        let viewModel = await makeScenario().viewModel
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        viewModel.edit.music = [music]
        viewModel.selection = .music(music.id)
        viewModel.perform(.replaceMusic)
        #expect(viewModel.sheet == .music)
        #expect(viewModel.musicReplacementID == music.id)
        viewModel.sheet = nil
        #expect(viewModel.musicReplacementID == nil)
    }

    @Test func theCaptionsMenuMakesOrManagesTheLines() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMenu(.captions))
        #expect(viewModel.toolbarContextLabel == "Captions")
        #expect(ids(viewModel) == ["autoCaptions", "writeCaptions"])
        viewModel.edit.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)]
        #expect(ids(viewModel) == ["addLine", "allLines", "style", "deleteAll"])
        #expect(viewModel.toolbarItems.last?.action == .deleteAllCaptions)
        #expect(viewModel.toolbarItems.last?.isPinned == true)
    }

    @Test func deleteIsPinnedAndTheOtherToolsScroll() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.toolbarItems.filter(\.isPinned).map(\.id) == ["delete"])
        #expect(viewModel.toolbarItems.last?.isPinned == true)
        viewModel.leaveToolbarContext()
        #expect(viewModel.toolbarItems.allSatisfy { !$0.isPinned })
    }

    // MARK: - Panels and selection

    @Test func aClipPanelClosesWhenTheClipIsLetGo() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.open(.speed))
        #expect(viewModel.panel == .speed)
        viewModel.selection = nil
        #expect(viewModel.panel == nil)
    }

    @Test func panelsOverTheWholeTakeStayWhenTheSelectionChanges() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.adjust))
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.selection = nil
        #expect(viewModel.panel == .adjust)
    }

    @Test func applyingClosesThePanelAndPauses() async {
        let scenario = await makeScenario()
        scenario.viewModel.perform(.open(.filters))
        scenario.player.play()
        scenario.viewModel.closePanel()
        #expect(scenario.viewModel.panel == nil)
        #expect(!scenario.player.isPlaying)
    }

    @Test func fullScreenLetsGoOfThePanelAndTheSelection() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.open(.speed))
        viewModel.toggleFullScreen()
        #expect(viewModel.isFullScreen)
        #expect(viewModel.selection == nil)
        #expect(viewModel.panel == nil)
        viewModel.toggleFullScreen()
        #expect(!viewModel.isFullScreen)
    }

    @Test func tappingBesideWhatsOnTheVideoLetsGoOfIt() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        viewModel.tapOutsideVideo()
        #expect(viewModel.selection == nil)
        #expect(viewModel.panel == nil)
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.tapOutsideVideo()
        #expect(viewModel.selection != nil)
    }

    // MARK: - Clips

    @Test func splitCutsAtThePlayheadAndPicksTheRightPart() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 7.1)
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.canSplitSelectedClip)
        viewModel.perform(.splitClip)
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 2)
        #expect(viewModel.selection == .clip(segments[1].id))
        #expect(scenario.toast.message == "Split at 00:07.1")
    }

    @Test func splitIsDimmedAndExplainsItselfAtTheClipsEdge() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 0.05)
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.toolbarItems.first?.style == .dimmed)
        viewModel.perform(.splitClip)
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move the playhead inside the clip")
    }

    @Test func splitAsksForThePlayheadOverThePickedClip() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.splitClip)
        let first = viewModel.edit.timeline.segments[0].id
        viewModel.selection = .clip(first)
        scenario.player.seek(to: 15)
        viewModel.perform(.splitClip)
        #expect(viewModel.edit.timeline.segments.count == 2)
        #expect(scenario.toast.message == "Move the playhead over this clip")
    }

    /// Task 1 of the prototype: cut "não, pera" out with Split + Delete.
    @Test func splitTwiceThenDeleteCutsAMistakeOut() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 7.1)
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.splitClip)
        scenario.player.seek(to: 10.1)
        viewModel.perform(.splitClip)
        let middle = viewModel.edit.timeline.segments[1].id
        viewModel.selection = .clip(middle)
        viewModel.perform(.deleteClip)
        #expect(viewModel.edit.timeline.segments.count == 2)
        #expect(abs(viewModel.edit.editedDuration - 18.6) < 0.001)
        #expect(viewModel.selection == nil)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 3)
    }

    @Test func aVideoKeepsAtLeastOneClip() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.deleteClip)
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "A video needs at least one clip")
    }

    @Test func duplicatePutsACopyRightAfterAndPicksIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        let original = viewModel.edit.timeline.segments[0]
        viewModel.perform(.duplicateClip)
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 2)
        #expect(segments[1].span == original.span)
        #expect(viewModel.selection == .clip(segments[1].id))
        #expect(abs(viewModel.edit.editedDuration - 43.2) < 0.001)
    }

    // MARK: - Texts and captions

    @Test func duplicatingATextPutsTheCopyALittleLower() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        let original = try #require(viewModel.selectedText)
        viewModel.perform(.duplicateText)
        let copy = try #require(viewModel.selectedText)
        #expect(copy.id != original.id)
        #expect(abs(copy.center.y - (original.center.y + 0.08)) < 0.001)
        #expect(viewModel.edit.texts.count == 2)
    }

    @Test func splittingALineAtThePlayheadPicksTheSecondPart() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let line = CaptionCue(text: "Massa fina, muito recheio", start: 12.4, end: 14.6, origin: .manual)
        viewModel.edit.captions = [line]
        viewModel.selection = .caption(line.id)
        scenario.player.seek(to: 13.5)
        viewModel.perform(.splitCaption)
        let lines = viewModel.edit.captions.sorted { $0.start < $1.start }
        #expect(lines.count == 2)
        #expect(lines[0].text == "Massa fina,")
        #expect(lines[1].text == "muito recheio")
        #expect(viewModel.selection == .caption(lines[1].id))
    }

    @Test func joiningTheLastLineSaysSo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let line = CaptionCue(text: "Segue pra ver os outros quatro.", start: 17.8, end: 20.6, origin: .manual)
        viewModel.edit.captions = [line]
        viewModel.selection = .caption(line.id)
        viewModel.perform(.joinCaption)
        #expect(scenario.toast.message == "This is the last line")
    }

    @Test func reRecordingAVoiceOverGoesBackToWhereItStarted() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 4)
        viewModel.edit.voiceOvers = [voice]
        viewModel.selection = .voiceOver(voice.id)
        scenario.player.seek(to: 12)
        viewModel.perform(.reRecordVoiceOver)
        #expect(viewModel.edit.voiceOvers.isEmpty)
        #expect(scenario.player.currentTime == 4)
        #expect(viewModel.panel == .voiceOver)
    }
}
