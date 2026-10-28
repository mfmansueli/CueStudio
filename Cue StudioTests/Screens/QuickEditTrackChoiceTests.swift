//
//  QuickEditTrackChoiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's current track (`QuickEditViewModel.tracks`): ▾ brings every track out, a tap on one only chooses it (no
/// tools, nothing added), an item picked anywhere (timeline, preview, a tool) brings its track, and the current track is kept
/// for the take.
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

    @Test func theChevronBringsEveryTrackOutAndATapOnOneOnlyChoosesIt() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.tracks == TimelineTrackChoice())
        #expect(viewModel.timelineInput(heightClass: .regular).tracks == viewModel.tracks)
        viewModel.tapTimeline(.trackChooser)
        #expect(viewModel.tracks.isExpanded)
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.tracks == TimelineTrackChoice(current: .captions))
        // Choosing only chose: no tools, nothing added.
        #expect(viewModel.toolMenu == nil)
        #expect(viewModel.panel == nil)
        #expect(viewModel.sheet == nil)
        // The next tap does what the track does.
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.toolMenu == .captions)
        // ▴ puts the tracks away as they were.
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.trackChooser)
        #expect(viewModel.tracks == TimelineTrackChoice(current: .captions))
    }

    @Test func choosingTheEmptyMediaTrackNeverOpensTheLibrary() async {
        let viewModel = await makeViewModel()
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.media))
        #expect(viewModel.sheet == nil)
        #expect(viewModel.tracks == TimelineTrackChoice(current: .media))
        viewModel.tapTimeline(.lane(.media))
        #expect(viewModel.sheet == .media)
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
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.selection = .clip(clip)
        viewModel.tapTimeline(.trackChooser)
        viewModel.tapTimeline(.lane(.text))
        #expect(viewModel.selection == .clip(clip))
        #expect(viewModel.tracks == TimelineTrackChoice(current: .text))
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
