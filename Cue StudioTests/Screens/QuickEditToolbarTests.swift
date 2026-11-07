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

    /// The main bar, in the picked clip's order (owner, 28/10/2026): the basics, the clip's essentials, its picture, the montage,
    /// the whole video.
    private static let mainIDs = [
        "edit", "split", "captions", "text", "pauses", "addMedia", "audio",
        "speed", "volume", "zoom",
        "adjustVideo", "skinVideo", "filters", "backgroundVideo", "clipCrop", "stabilize", "blurArea", "copyLook", "pasteLook",
        "clipAnimation", "duplicate", "freeze", "reverse", "replace", "reorder", "extractAudio",
        "editByText", "voice", "format", "templates", "brandKit", "cover",
    ]

    /// What every item's bar (but a clip's) offers after its own tools.
    private static let itemShortcutIDs = [
        "clipTools", "captions", "text", "addMedia", "audio", "pauses", "editByText",
        "format", "adjustVideo", "skinVideo", "filters", "backgroundVideo", "blurArea", "templates", "brandKit", "cover",
    ]

    /// The ids after the bar's first thin line (its own tools come before it), Delete left out.
    private func shortcuts(_ viewModel: QuickEditViewModel) -> [String] {
        let items = viewModel.toolbarItems.filter { !$0.isPinned }
        guard let start = items.firstIndex(where: \.startsGroup) else { return [] }
        return items[start...].map(\.id)
    }

    // MARK: - Contexts

    @Test func theMainToolbarHasEveryToolWithNothingPicked() async {
        let viewModel = await makeScenario().viewModel
        #expect(ids(viewModel) == Self.mainIDs)
        #expect(viewModel.toolbarItems.count == 32)
        #expect(viewModel.toolbarContext == .main)
        // A thin line starts each group after the basics.
        #expect(viewModel.toolbarItems.enumerated().filter(\.element.startsGroup).map(\.offset) == [7, 10, 19, 26])
        // Only the four whose name a clip's bar also has carry the whole video's badge (owner, 07/11/2026); nothing to delete.
        #expect(viewModel.toolbarItems.filter { $0.scopeBadge == .wholeVideo }.map(\.id) == ["adjustVideo", "skinVideo", "filters", "backgroundVideo"])
        #expect(viewModel.toolbarItems.allSatisfy { !$0.isPinned })
    }

    @Test func formatIsOnTheMainBarAndOpensTheFormatPanel() async {
        let viewModel = await makeScenario().viewModel
        let format = viewModel.toolbarItems.first { $0.id == "format" }
        #expect(format?.label == "Aspect ratio")
        #expect(format?.action == .open(.crop))
        viewModel.perform(.open(.crop))
        #expect(viewModel.panel == .crop)
        #expect(EditorPanel.crop.title == "Aspect ratio")
    }

    /// The speech clean-up is the fifth, among the five on screen, where ✦ Smart was (owner, 07/11/2026).
    @Test func cleanUpIsFifth() async {
        let viewModel = await makeScenario().viewModel
        let items = viewModel.toolbarItems
        #expect(items[4].id == "pauses")
        #expect(items[4].label == "Clean up")
        #expect(items[4].action == .open(.pauses))
        #expect(items.last?.id == "cover")
        // One clip and no look copied: Reorder and Paste look say why when tapped.
        #expect(items.filter { $0.style == .dimmed }.map(\.id) == ["pasteLook", "reorder"])
        #expect(items.first { $0.id == "cover" }?.action == .openCoverStudio)
        #expect(items.first { $0.id == "templates" }?.action == .openTemplates(.templates))
        #expect(items.first { $0.id == "brandKit" }?.action == .openTemplates(.brand))
        #expect(items.first { $0.id == "skinVideo" }?.action == .openLook(.skin, wholeVideo: true))
        #expect(items.first { $0.id == "brandKit" }?.label == TemplatesPanelSection.brand.label)
    }

    @Test func theClipBarHasItsOwnToolsThenTheOthers() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        let items = viewModel.toolbarItems
        // Its look is the clip's (Adjust, Skin, Filters, Background), its picture's group.
        #expect(items.first { $0.id == "adjust" }?.action == .openLook(.adjust, wholeVideo: false))
        #expect(items.first { $0.id == "skin" }?.action == .openLook(.skin, wholeVideo: false))
        // Five groups: its essentials, its picture, the montage, what goes on top, the whole video.
        #expect(items.filter(\.startsGroup).map(\.id) == ["adjust", "transition", "text", "pauses"])
        // Everything that reaches past the clip is in the last group, and says so.
        #expect(items.filter { $0.scopeBadge != nil }.map(\.id) == ["pauses", "editByText", "voice", "captions", "format", "templates", "brandKit"])
        #expect(items.last?.id == "delete")
    }

    /// Audio: music, sound effects and voice-over; then, past a thin line, Studio Voice and the sound of the clip under the playhead.
    @Test func theAudioMenuNamesStudioVoice() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMenu(.audio))
        #expect(ids(viewModel) == ["music", "soundEffects", "voiceOver", "textToSpeech", "voice", "volume", "voiceEffects", "extractAudio"])
        #expect(viewModel.toolbarItems.first { $0.id == "voice" }?.label == "Studio Voice")
        #expect(viewModel.toolbarItems.first { $0.id == "voice" }?.startsGroup == true)
        viewModel.perform(.openSoundEffects)
        #expect(viewModel.sheet == .soundEffects)
    }

    /// Mute is Volume's "Mute this clip" on the clip's bar: lit while the clip is silent, one undo step. Transition, with one clip,
    /// says how to make a cut; with cuts it opens the one after the clip (the last clip's, the one before it).
    @Test func theClipBarsMuteAndTransition() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        let mute = { viewModel.toolbarItems.first { $0.id == "mute" } }
        #expect(mute()?.isOn == false)
        viewModel.perform(.toggleClipMute)
        #expect(viewModel.edit.timeline.segments[0].isMuted)
        #expect(mute()?.isOn == true)
        viewModel.undo()
        #expect(!viewModel.edit.timeline.segments[0].isMuted)
        #expect(viewModel.toolbarItems.first { $0.id == "transition" }?.style == .dimmed)
        viewModel.perform(.openClipTransition)
        #expect(scenario.toast.message == "Split or add a clip to add a transition")
        for cut in [7.0, 14] {
            var timeline = viewModel.edit.timeline
            timeline.split(atEdited: cut)
            viewModel.commit(timeline)
        }
        let segments = viewModel.edit.timeline.segments
        viewModel.selection = .clip(segments[0].id)
        #expect(viewModel.toolbarItems.first { $0.id == "transition" }?.style == .normal)
        viewModel.perform(.openClipTransition)
        #expect(viewModel.selection == .join(segments[1].id))
        #expect(viewModel.panel == .transition)
        viewModel.selection = .clip(segments[2].id)
        viewModel.perform(.openClipTransition)
        #expect(viewModel.selection == .join(segments[2].id))
    }

    @Test func editPicksTheClipUnderThePlayheadAndShowsItsTools() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.selection == .clip(viewModel.edit.timeline.segments[0].id))
        #expect(viewModel.toolbarContext == .clip)
        #expect(ids(viewModel) == [
            "split", "speed", "volume", "mute", "zoom",
            "adjust", "skin", "filters", "background", "clipCrop", "mirror", "stabilize", "blurArea", "copyLook", "pasteLook",
            "transition", "clipAnimation", "duplicate", "freeze", "reverse", "replace", "reorder", "extractAudio", "voiceEffects", "resetClip",
            "text", "addMedia", "audio",
            "pauses", "editByText", "voice", "captions", "format", "templates", "brandKit", "cover", "delete",
        ])
        #expect(viewModel.toolbarItems.last?.style == .destructive)
    }

    /// Edit (the scissors) is where a creator goes to cut a mistake: right after Split, the other ways to cut, over
    /// the whole video.
    @Test func theClipToolsOfferTheOtherWaysToCutRightAfterSplit() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.toolbarItems.first { $0.id == "editByText" }?.action == .editByText)
        #expect(viewModel.toolbarItems.first { $0.id == "pauses" }?.action == .open(.pauses))
        viewModel.perform(.open(.pauses))
        #expect(viewModel.panel == .pauses)
        // The clip stays picked: ✓ brings its tools back.
        #expect(viewModel.selection?.clipID != nil)
        viewModel.perform(.editByText)
        #expect(viewModel.panel == .pauses && viewModel.panelTab == .transcript)
    }

    /// The back button says which item the tools change: the clip's number in a montage, a photo or a video, a text's kind.
    @Test func theBackButtonNamesThePickedItem() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.toolbarContextName == "Clip")
        scenario.player.seek(to: 7.1)
        viewModel.perform(.splitClip)
        #expect(viewModel.toolbarContextName == "Clip 2")
        // The kind stays the tools' identity: picking another clip keeps them where they were scrolled.
        #expect(viewModel.toolbarContext == .clip)
        viewModel.perform(.addText(.hook))
        #expect(viewModel.toolbarContextName == "Hook")
        viewModel.overlays.addMedia(ImportedMedia(kind: .photo, fileName: "photo-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
        #expect(viewModel.toolbarContextName == "Photo")
        viewModel.selection = nil
        viewModel.perform(.openMenu(.audio))
        #expect(viewModel.toolbarContextName == "Audio")
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
        #expect(viewModel.toolbarContext == .text)
        #expect(ids(viewModel) == ["editText", "style", "animation", "keyframe", "track", "duplicate", "lock"] + Self.itemShortcutIDs + ["delete"])
        let line = CaptionCue(text: "Massa fina, muito recheio", start: 12.4, end: 14.6, origin: .manual)
        viewModel.changeEdit { $0.captions = [line] }
        viewModel.selection = .caption(line.id)
        #expect(viewModel.toolbarContext == .caption)
        // Edit opens the Captions panel on the line already: no second way to the same list.
        #expect(ids(viewModel) == ["editCaption", "style", "split", "join", "emphasis"] + Self.itemShortcutIDs.filter { $0 != "captions" } + ["delete"])
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        viewModel.changeEdit { $0.music = [music] }
        viewModel.selection = .music(music.id)
        #expect(ids(viewModel) == ["volume", "beats", "replace", "lock"] + Self.itemShortcutIDs + ["delete"])
        let voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)
        viewModel.changeEdit { $0.voiceOvers = [voice] }
        viewModel.selection = .voiceOver(voice.id)
        #expect(ids(viewModel) == ["volume", "reRecord", "voiceEffects", "lock"] + Self.itemShortcutIDs + ["delete"])
    }

    @Test func aTextsAnimationToolOpensItsStyleOnTheMotionTab() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        viewModel.closePanel()
        let animation = try #require(viewModel.toolbarItems.first { $0.id == "animation" })
        #expect(animation.label == "Motion")
        #expect(animation.action == .openTextAnimation)
        viewModel.perform(animation.action)
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.panelTab == .motion)
        #expect(viewModel.overlays.textStyleScope == .selected)
    }

    @Test func aPickedMediaCanBeDuplicatedFromItsTools() async throws {
        let viewModel = await makeScenario().viewModel
        let media = MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 2, end: 5))
        viewModel.changeEdit { $0.media = [media] }
        viewModel.selection = .media(media.id)
        #expect(ids(viewModel) == [
            "editMedia", "mediaMotion", "mask", "splitMedia", "replaceMedia", "blurArea", "track", "keyframe", "duplicate", "saveToLibrary", "lock",
        ] + Self.itemShortcutIDs.filter { $0 != "blurArea" } + ["delete"])
        viewModel.perform(.duplicateMedia)
        #expect(viewModel.edit.media.count == 2)
        #expect(viewModel.selection != .media(media.id))
    }

    @Test func lockKeepsAPickedLayerInPlaceUntilItIsUnlockedAndIsSaved() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        viewModel.closePanel()
        let id = try #require(viewModel.selection?.textID)
        viewModel.perform(.toggleLock)
        #expect(viewModel.edit.lockedLayers == [id])
        #expect(viewModel.toolbarItems.contains { $0.id == "unlock" })
        let saved = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(viewModel.edit))
        #expect(saved.lockedLayers == [id])
        viewModel.perform(.toggleLock)
        #expect(viewModel.edit.lockedLayers.isEmpty)
        #expect(viewModel.toolbarItems.contains { $0.id == "lock" })
    }

    @Test func textAndAudioMenus() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMenu(.text))
        #expect(viewModel.toolbarContext == .menu(.text))
        #expect(ids(viewModel) == ["title", "subtitle", "hook", "callout", "graphic.arrow", "graphic.circle", "graphic.tag", "brandKit"])
        #expect(viewModel.toolbarItems.last?.action == .openTemplates(.brand))
        viewModel.perform(.addText(.hook))
        viewModel.leaveToolbarContext()
        viewModel.perform(.openMenu(.text))
        #expect(ids(viewModel).suffix(2) == ["styleAll", "brandKit"])
        viewModel.perform(.openMenu(.audio))
        #expect(ids(viewModel) == ["music", "soundEffects", "voiceOver", "textToSpeech", "voice", "volume", "voiceEffects", "extractAudio"])
        viewModel.leaveToolbarContext()
        #expect(viewModel.toolbarContext == .main)
        #expect(viewModel.toolMenu == nil)
    }

    @Test func addingATextOpensTextStyleWithTheKeyboard() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMenu(.text))
        viewModel.perform(.addText(.title))
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.overlays.focusesTextField)
        #expect(viewModel.overlays.textStyleScope == .selected)
        #expect(viewModel.overlays.editingTextID == nil)
        #expect(viewModel.panelSubtitle(.textStyle) == "Only this title changes")
    }

    @Test func styleAllOpensTextStyleForEveryText() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.title))
        viewModel.perform(.addText(.hook))
        viewModel.leaveToolbarContext()
        viewModel.perform(.styleAllTexts)
        #expect(viewModel.overlays.textStyleScope == .allTexts)
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.panelSubtitle(.textStyle) == "All 2 texts change together")
    }

    @Test func captionsOpenAutoCaptionsUntilThereAreLines() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openCaptions)
        #expect(viewModel.panel == .autoCaptions)
        viewModel.changeEdit { $0.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)] }
        viewModel.perform(.openCaptions)
        #expect(viewModel.panel == .captions)
    }

    @Test func musicAlwaysOpensFilesToAddAClipAtThePlayhead() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openMusic)
        #expect(viewModel.sheet == .music)
        #expect(viewModel.audio.musicReplacementID == nil)
        viewModel.sheet = nil
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        viewModel.changeEdit { $0.music = [music] }
        viewModel.perform(.openMusic)
        #expect(viewModel.sheet == .music)
        #expect(viewModel.selection == nil)
    }

    @Test func replaceAsksForAFileForThePickedClipOnly() async {
        let viewModel = await makeScenario().viewModel
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        viewModel.changeEdit { $0.music = [music] }
        viewModel.selection = .music(music.id)
        viewModel.perform(.replaceMusic)
        #expect(viewModel.sheet == .music)
        #expect(viewModel.audio.musicReplacementID == music.id)
        viewModel.sheet = nil
        #expect(viewModel.audio.musicReplacementID == nil)
    }

    /// Blur area's faces step has ◐ once there are areas: the whole video without them, while it is open (owner, 07/11/2026).
    @Test func theBlurFacesStepComparesTheWholeSetWhileOpen() async {
        let viewModel = await makeScenario().viewModel
        #expect(!viewModel.blur.blurCompare.isEnabled)
        let area = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 2), box: NormalizedBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
        viewModel.changeEdit { $0.blurRegions = [area] }
        #expect(viewModel.blur.blurCompare.isEnabled)
        viewModel.perform(.addBlurArea)
        #expect(viewModel.panel == .blur)
        viewModel.blur.comparesOriginal = true
        let comparing = viewModel.blur.comparesOriginal
        #expect(comparing)
        viewModel.closePanel()
        let afterClosing = viewModel.blur.comparesOriginal
        #expect(!afterClosing, "◐ ends with the panel")
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

    /// The arrow at the video's foot and its swipe: with nothing open over the video and in full screen, not under a panel.
    @Test func theFullScreenSwipeIsThereWithNothingOverTheVideo() async {
        let viewModel = await makeScenario().viewModel
        #expect(viewModel.swipesFullScreen)
        viewModel.perform(.open(.filters))
        #expect(!viewModel.swipesFullScreen)
        viewModel.toggleFullScreen()
        #expect(viewModel.swipesFullScreen)
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
        #expect(viewModel.clips.canSplitSelectedClip)
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
        #expect(scenario.toast.message == "Move playhead onto the clip")
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
        #expect(scenario.toast.message == "Move playhead onto the clip")
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
        #expect(scenario.toast.message == "Keep at least one clip")
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
        viewModel.changeEdit { $0.captions = [line] }
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
        viewModel.changeEdit { $0.captions = [line] }
        viewModel.selection = .caption(line.id)
        viewModel.perform(.joinCaption)
        #expect(scenario.toast.message == "This is the last line")
    }

    @Test func reRecordingAVoiceOverGoesBackToWhereItStarted() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 4)
        viewModel.changeEdit { $0.voiceOvers = [voice] }
        viewModel.selection = .voiceOver(voice.id)
        scenario.player.seek(to: 12)
        viewModel.perform(.reRecordVoiceOver)
        #expect(viewModel.edit.voiceOvers.isEmpty)
        #expect(scenario.player.currentTime == 4)
        #expect(viewModel.panel == .voiceOver)
    }

    // MARK: - More tools on every bar (26/10/2026)

    /// Every bar the editor can show, with the item picked for it.
    private func everyBar(_ scenario: Scenario) -> [(String, [EditorToolbarItem])] {
        let viewModel = scenario.viewModel
        var bars: [(String, [EditorToolbarItem])] = [("main", viewModel.toolbarItems)]
        for menu in [EditorToolMenu.text, .audio, .media] {
            viewModel.perform(.openMenu(menu))
            bars.append(("menu \(menu)", viewModel.toolbarItems))
        }
        viewModel.leaveToolbarContext()
        viewModel.perform(.selectClipAtPlayhead)
        bars.append(("clip", viewModel.toolbarItems))
        viewModel.perform(.addText(.title))
        bars.append(("text", viewModel.toolbarItems))
        let line = CaptionCue(text: "Massa fina, muito recheio", start: 12.4, end: 14.6, origin: .manual)
        let music = MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: 0, length: 10)
        let voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)
        let window = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 1, mediaDuration: 6, span: TimeSpan(start: 2, end: 5))
        viewModel.changeEdit { edit in
            edit.captions = [line]
            edit.music = [music]
            edit.voiceOvers = [voice]
            edit.media = [window]
        }
        let picks: [(String, EditorSelection)] = [
            ("caption", .caption(line.id)), ("music", .music(music.id)), ("voice-over", .voiceOver(voice.id)), ("media", .media(window.id)),
        ]
        for (name, selection) in picks {
            viewModel.selection = selection
            bars.append((name, viewModel.toolbarItems))
        }
        return bars
    }

    @Test func noBarShowsTheSameToolTwice() async {
        for (name, items) in everyBar(await makeScenario()) {
            #expect(Set(items.map(\.id)).count == items.count, "\(name) repeats \(items.map(\.id))")
            #expect(Set(items.map(\.action)).count == items.count, "\(name) has two buttons doing the same")
            // Delete, where there is one, is the only pinned tool and the last.
            #expect(items.filter(\.isPinned).count <= 1, "\(name)")
            if let pinned = items.firstIndex(where: \.isPinned) { #expect(pinned == items.count - 1, "\(name)") }
        }
    }

    /// Next to a text, a caption, a photo or a sound, nothing of the video's own (Split, Speed, Volume, Zoom…) is added: it would read
    /// as acting on the item. Their own Split and Volume stay.
    @Test func anItemsBarNeverAddsTheVideosClipTools() async {
        let videoTools: Set<EditorAction> = [
            .splitClip, .open(.speed), .open(.zoom), .open(.stabilize), .duplicateClip, .freezeFrame, .reverseClip, .replaceClip,
            .reorderClips, .copyLook, .pasteLook,
        ]
        let bars = everyBar(await makeScenario())
        for (name, items) in bars where !["main", "clip"].contains(name) && !name.hasPrefix("menu") {
            #expect(items.allSatisfy { !videoTools.contains($0.action) }, "\(name)")
            // The volume tool of a sound or a video is its own, before the thin line.
            let own = items.prefix { !$0.startsGroup }
            #expect(items.filter { $0.action == .open(.volume) }.allSatisfy { item in own.contains(item) }, "\(name)")
        }
        let bar = Dictionary(uniqueKeysWithValues: bars)
        #expect(bar["caption"]?.contains { $0.action == .splitCaption } == true)
        #expect(bar["media"]?.contains { $0.action == .splitMedia } == true)
        #expect(bar["music"]?.first?.action == .open(.volume))
    }

    @Test func theOtherToolsComeAfterTheItemsOwnAndSayWhenTheyReachTheWholeVideo() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.addText(.hook))
        #expect(shortcuts(viewModel) == Self.itemShortcutIDs)
        let badged = viewModel.toolbarItems.filter { $0.scopeBadge == .wholeVideo }.map(\.id)
        #expect(badged == ["captions", "pauses", "editByText", "format", "adjustVideo", "skinVideo", "filters", "backgroundVideo", "templates", "brandKit"])
        // "Clip" goes to the tools of the clip under the playhead.
        #expect(viewModel.toolbarItems.first { $0.id == "clipTools" }?.action == .selectClipAtPlayhead)
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.toolbarContext == .clip)
    }

    @Test func theMainVideosAreaOfASplitScreenAddsTheOthersButNeverDelete() async throws {
        let viewModel = await makeScenario().viewModel
        var support = MediaOverlay(kind: .video, fileName: "s.mov", aspect: 1, mediaDuration: 6, span: TimeSpan(start: 2, end: 5))
        support.layout = .split
        viewModel.changeEdit { $0.media = [support] }
        viewModel.selection = .media(support.id)
        viewModel.overlays.selectedArea = .main
        #expect(viewModel.toolbarContext == .mainArea)
        #expect(viewModel.toolbarContextName == "Main video")
        // Its own Clip and Blur area stay where they were; nothing deletes (the support would go).
        #expect(Array(ids(viewModel).prefix(5)) == ["framing", "swap", "layout", "clipTools", "blurArea"])
        #expect(shortcuts(viewModel) == Self.itemShortcutIDs.filter { !["clipTools", "blurArea"].contains($0) })
        #expect(!viewModel.toolbarItems.contains { $0.isPinned })
    }

    /// A badged tool on an item's bar says once, per tool and kind of item, that it changes the whole video; the main bar never.
    @Test func aWholeVideoToolOnAnItemsBarSaysItsReachOnce() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let format = try #require(viewModel.toolbarItems.first { $0.id == "format" })
        viewModel.tap(format)
        #expect(viewModel.panel == .crop)
        #expect(scenario.toast.message == nil)
        viewModel.closePanel()
        scenario.player.seek(to: 7.1)
        viewModel.perform(.splitClip)
        let clipFormat = try #require(viewModel.toolbarItems.first { $0.id == "format" })
        viewModel.tap(clipFormat)
        #expect(scenario.toast.message == "Applies to the whole video, not only to Clip 2.")
        #expect(viewModel.panel == .crop)
        viewModel.closePanel()
        scenario.toast.dismiss()
        viewModel.tap(clipFormat)
        #expect(scenario.toast.message == nil, "said once per tool and kind of item")
        viewModel.closePanel()
        // Another tool, or the same on another kind of item, says it again.
        let templates = try #require(viewModel.toolbarItems.first { $0.id == "templates" })
        viewModel.tap(templates)
        #expect(scenario.toast.message == "Applies to the whole video, not only to Clip 2.")
        viewModel.closePanel()
        scenario.toast.dismiss()
        viewModel.perform(.addText(.hook))
        viewModel.closePanel()
        let hookFormat = try #require(viewModel.toolbarItems.first { $0.id == "format" })
        viewModel.tap(hookFormat)
        #expect(scenario.toast.message == "Applies to the whole video, not only to Hook.")
    }

    @Test func templatesAndBrandKitOpenThePanelOnTheirTab() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.openTemplates(.templates))
        #expect(viewModel.panel == .templates)
        #expect(viewModel.templatesSection == .templates)
        // Already open: the tab changes.
        viewModel.perform(.openTemplates(.brand))
        #expect(viewModel.templatesSection == .brand)
        viewModel.closePanel()
        viewModel.perform(.openTemplates(.templates))
        #expect(viewModel.templatesSection == .templates)
    }

    @Test func skinOpensItsOwnPanelAtTheButtonsReachApplyingNothing() async {
        let viewModel = await makeScenario().viewModel
        let before = viewModel.edit
        viewModel.perform(.openLook(.skin, wholeVideo: true))
        #expect(viewModel.panel == .skin)
        #expect(!viewModel.look.lookScopeIsClip)
        #expect(viewModel.edit == before && !viewModel.canUndo, "opening Skin applies nothing")
        viewModel.closePanel()
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.openLook(.skin, wholeVideo: false))
        #expect(viewModel.look.lookScopeIsClip)
        viewModel.closePanel()
        // From a text's bar, the badged Skin is the whole video's.
        viewModel.perform(.addText(.title))
        viewModel.closePanel()
        viewModel.perform(.openLook(.skin, wholeVideo: true))
        #expect(!viewModel.look.lookScopeIsClip)
        #expect(viewModel.selection?.textID != nil, "the text stays picked: ✓ brings its tools back")
    }
}
