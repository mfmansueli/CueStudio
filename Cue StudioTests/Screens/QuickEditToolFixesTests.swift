//
//  QuickEditToolFixesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Canvas 2's independent fixes (owner, 07/11/2026): a video over the take gets a Volume Reset of its own (bug 1), Beats names
/// where the music came from and the interval it cuts on (bug 5, F11), Transition's copy counts the cuts and offers Undo (F7),
/// a caption's bar has Style right after Edit (N2), and a clip's Volume grows while Advanced is open.
@MainActor
@Suite("Quick edit · canvas 2's independent fixes")
struct QuickEditToolFixesTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, toast: toast)
    }

    private func soundingVideo(keptSound: Bool) -> MediaOverlay {
        var media = MediaOverlay(kind: .video, fileName: "broll.mov", aspect: 1, mediaDuration: 8, span: TimeSpan(start: 4, end: 7))
        media.hasSound = true
        if keptSound {
            media.audioVolume = 1
            media.keptSoundWhenAdded = true
        }
        return media
    }

    // MARK: - Bug 1

    @Test func aVideosVolumeResetPutsBackOnlyItsSoundAsItCameIn() async throws {
        let viewModel = await makeScenario().viewModel
        // The main clip's volume changed too: Reset on the video must leave it alone.
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.clips.setTargetVolume(1.5)
        let media = soundingVideo(keptSound: false)
        viewModel.change { $0.media = [media] }
        viewModel.selection = .media(media.id)
        viewModel.perform(.open(.volume))
        #expect(viewModel.panelReset(.volume) == nil, "Nothing to put back yet: it came in muted")
        viewModel.overlays.setMediaSoundVolume(media.id, 0.4)
        let reset = try #require(viewModel.panelReset(.volume))
        reset()
        #expect(viewModel.edit.media[0].audioVolume == nil)
        #expect(viewModel.edit.timeline.segments[0].volume == 1.5)
        viewModel.undo()
        #expect(viewModel.edit.media[0].audioVolume == 0.4)
    }

    @Test func aVideoWhoseSoundWasKeptResetsToFull() async throws {
        let viewModel = await makeScenario().viewModel
        let media = soundingVideo(keptSound: true)
        viewModel.change { $0.media = [media] }
        viewModel.selection = .media(media.id)
        #expect(viewModel.panelReset(.volume) == nil)
        viewModel.overlays.setMediaSoundVolume(media.id, 0.3)
        let reset = try #require(viewModel.panelReset(.volume))
        reset()
        #expect(viewModel.edit.media[0].audioVolume == 1)
    }

    @Test func keepingASoundWhenAddedIsRemembered() async {
        let viewModel = await makeScenario().viewModel
        let media = soundingVideo(keptSound: false)
        viewModel.change { $0.media = [media] }
        viewModel.overlays.chooseSound(for: media.id, keeps: true)
        #expect(viewModel.edit.media[0].audioVolume == 1 && viewModel.edit.media[0].keptSoundWhenAdded == true)
    }

    // MARK: - Bug 5 and F11

    @Test func beatsSaysWhereTheMusicCameFrom() async {
        let viewModel = await makeScenario().viewModel
        var files = MusicClip(fileName: "song.m4a", title: "Song", fileDuration: 20, start: 0, length: 20)
        var cue = MusicClip(fileName: "cue.m4a", title: "Clean Slate", fileDuration: 20, start: 0, length: 20)
        cue.libraryTrack = .cleanSlate
        files.id = UUID()
        viewModel.changeEdit { $0.music = [files, cue] }
        viewModel.selection = .music(files.id)
        #expect(viewModel.audio.beatsSourceNote == String(localized: "Found on your iPhone in the music you added from Files."))
        viewModel.selection = .music(cue.id)
        #expect(viewModel.audio.beatsSourceNote == String(localized: "Found on your iPhone in this music from Cue."))
    }

    @Test func theCutButtonNamesItsInterval() {
        #expect(BeatsPanel.cutLabel(every: 1) == String(localized: "Cut on every beat"))
        #expect(BeatsPanel.cutLabel(every: 2) == String(localized: "Cut every 2 beats"))
        #expect(BeatsPanel.cutLabel(every: 4) == String(localized: "Cut every 4 beats"))
    }

    // MARK: - F7

    @Test func transitionOnEveryCutCountsThemAndOffersUndo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 5)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 15)
        viewModel.commit(timeline)
        viewModel.selectedJoinID = viewModel.edit.timeline.segments[1].id
        viewModel.clips.setTransition(.dissolve)
        viewModel.clips.setTransitionOnEveryCut(.dissolve)
        #expect(scenario.toast.message == String(localized: "\(EditTransition.dissolve.label) on all \(3) cuts"))
        #expect(scenario.toast.action != nil, "No Undo on the toast")
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[2].transitionIn != .dissolve)
    }

    // MARK: - Volume › Advanced

    @Test func aClipsVolumeGrowsWhileAdvancedIsOpen() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.selectClipAtPlayhead)
        viewModel.perform(.open(.volume))
        #expect(viewModel.openPanelSize == EditorPanel.volume.size)
        viewModel.showsAdvanced = true
        #expect(viewModel.openPanelSize == .medium)
    }
}
