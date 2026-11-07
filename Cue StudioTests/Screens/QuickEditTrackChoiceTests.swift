//
//  QuickEditTrackChoiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's current track (`QuickEditViewModel.tracks`): ▾ brings every track out, a tap on one chooses it and opens its
/// tools (nothing added; under a panel it only chooses), an item picked anywhere (timeline, preview, a tool) brings its track,
/// and the current track is kept for the take.
@MainActor
@Suite("Quick edit · the current track")
struct QuickEditTrackChoiceTests {
    private func makeViewModel(take: Take? = nil, preferences: FakeEditorPreferencesStore = FakeEditorPreferencesStore()) async
        -> QuickEditViewModel {
        let take = take ?? TestData.take(scriptID: nil, number: 1)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = take.duration
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), styles: FakeTextStyleStore(), editorPreferences: preferences
        )
        await viewModel.prepare()
        return viewModel
    }

    private func addMusic(to viewModel: QuickEditViewModel) -> UUID {
        let music = MusicClip(fileName: "song.m4a", title: "Song", fileDuration: 30, start: 0, length: 5)
        viewModel.changeEdit { $0.music = [music] }
        return music.id
    }

    @Test func theChevronBringsEveryTrackOutAndATapOnOneChoosesItWithItsTools() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.tracks == TimelineTrackChoice())
        #expect(viewModel.timelineInput(heightClass: .regular).tracks == viewModel.tracks)
        viewModel.tapTimeline(.trackChooser)
        #expect(viewModel.tracks.isExpanded)
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.tracks == TimelineTrackChoice(current: .captions))
        // It comes with its panel open, the one the main bar's Captions opens, nothing added.
        #expect(viewModel.toolMenu == nil)
        #expect(viewModel.panel == .captions || viewModel.panel == .autoCaptions)
        #expect(viewModel.sheet == nil)
        // Under the panel, a tap only chooses.
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.tracks.current == .captions)
        // ▴ puts the tracks away as they were.
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.trackChooser)
        #expect(viewModel.tracks == TimelineTrackChoice(current: .captions))
    }

    /// Photos and videos have their own bar (owner, 28/10/2026); the library opens from it, never from the track itself. The Blur
    /// area track opens what the main bar's Blur area opens: the faces in the frame (owner, 07/11/2026).
    @Test func theMediaTrackOpensItsBarAndTheBlurTrackItsPanel() async {
        let viewModel = await makeViewModel()
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.media))
        #expect(viewModel.sheet == nil)
        #expect(viewModel.tracks == TimelineTrackChoice(current: .media))
        #expect(viewModel.toolMenu == .media)
        viewModel.tapTimeline(.lane(.media))
        #expect(viewModel.toolMenu == nil)
        #expect(viewModel.sheet == nil)
        viewModel.tapTimeline(.lane(.media))
        #expect(viewModel.toolMenu == .media)
        viewModel.tapTimeline(.lane(.blur))
        #expect(viewModel.toolMenu == nil)
        #expect(viewModel.panel == .blur)
        #expect(viewModel.blur.picking != nil)
        #expect(viewModel.tracks.current == .blur)
    }

    @Test func anItemPickedAnywhereBringsItsTrack() async {
        let viewModel = await makeViewModel()
        let song = addMusic(to: viewModel)
        viewModel.tapTimeline(.trackChooser)
        // The preview, the timeline and the tools all pick through `selection`.
        viewModel.selection = .music(song)
        #expect(viewModel.tracks == TimelineTrackChoice(current: .music))
        // The video's clip leaves the track as it is.
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        #expect(viewModel.tracks.current == .music)
        // A panel about one track brings it, and so does a track's menu (the first audio track the edit has).
        viewModel.selection = nil
        viewModel.panel = .captions
        #expect(viewModel.tracks.current == .captions)
        viewModel.panel = nil
        viewModel.toolMenu = .audio
        #expect(viewModel.tracks.current == .music)
    }

    @Test func choosingAnotherTrackLetsGoOfAnItemOnTheOneBeforeButNotOfAClip() async {
        let viewModel = await makeViewModel()
        let song = addMusic(to: viewModel)
        viewModel.selection = .music(song)
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.selection == nil)
        // Under a panel a tap only chooses: a clip stays picked. Without one the track's tools open and let go of it, as a tap
        // on its strip does.
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.selection = .clip(clip)
        viewModel.panel = .speed
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.media))
        #expect(viewModel.selection == .clip(clip))
        #expect(viewModel.tracks == TimelineTrackChoice(current: .media))
        viewModel.panel = nil
        viewModel.selection = .clip(clip)
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.text))
        #expect(viewModel.selection == nil)
        #expect(viewModel.toolMenu == .text)
    }

    /// Audio's tools opened from the voice-over's track keep the voice-over under the video (the music's track doesn't take
    /// its place).
    @Test func audiosToolsKeepTheTrackTheyWereOpenedFrom() async {
        let viewModel = await makeViewModel()
        _ = addMusic(to: viewModel)
        viewModel.changeEdit { $0.voiceOvers = [VoiceOverClip(fileName: "voice.m4a", duration: 3, anchor: 0)] }
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.voiceOver))
        #expect(viewModel.toolMenu == .audio)
        #expect(viewModel.tracks == TimelineTrackChoice(current: .voiceOver))
    }

    @Test func underAPanelATapOnATrackOnlyChoosesIt() async {
        let viewModel = await makeViewModel()
        viewModel.tapTimeline(.trackChooser)
        viewModel.panel = .volume
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.panel == .volume)
        #expect(viewModel.toolMenu == nil)
        #expect(viewModel.tracks.current == .captions)
    }

    @Test func theCurrentTrackIsKeptForTheTake() async {
        let preferences = FakeEditorPreferencesStore()
        let viewModel = await makeViewModel(preferences: preferences)
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.captions))
        #expect(preferences.timelineLane(forTake: viewModel.take.id) == .captions)
        // Opened again, collapsed on it.
        let again = await makeViewModel(take: viewModel.take, preferences: preferences)
        #expect(again.tracks == TimelineTrackChoice(current: .captions))
        // Another take starts on Texts.
        let other = await makeViewModel(preferences: preferences)
        #expect(other.tracks == TimelineTrackChoice())
    }

    @Test func theDevicesStoreKeepsTheLastTakesOnly() throws {
        let defaults = try #require(UserDefaults(suiteName: "QuickEditTrackChoiceTests.\(UUID().uuidString)"))
        let store = EditorPreferencesStore(defaults: defaults)
        let first = UUID()
        store.setTimelineLane(.music, forTake: first)
        store.setTimelineLane(.captions, forTake: first)
        #expect(store.timelineLane(forTake: first) == .captions)
        #expect(store.timelineLane(forTake: UUID()) == nil)
        for _ in 0..<EditorPreferencesStore.keptTimelineLanes {
            store.setTimelineLane(.text, forTake: UUID())
        }
        #expect(store.timelineLane(forTake: first) == nil)
        #expect(defaults.stringArray(forKey: DefaultsKey.timelineLanes)?.count == EditorPreferencesStore.keptTimelineLanes)
    }
}
