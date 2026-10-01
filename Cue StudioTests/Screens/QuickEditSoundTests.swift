//
//  QuickEditSoundTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Sound in Quick edit: music from Files at the playhead, moved and trimmed on its track with the
/// file following, its volume and fades as undo steps; the Voice levels (an old edit moves to them
/// only when one is touched) and "Compare with original" at the same loudness; and a video's own
/// sound, kept or muted.
@MainActor
@Suite("Quick edit sound")
struct QuickEditSoundTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let toast: ToastService
        let importer: FakeMediaImporter
    }

    private func makeScenario(edit: TakeEdit? = nil) async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let editor = FakeTakeEditor()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let importer = FakeMediaImporter()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: importer, recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor, player: player, toast: toast, importer: importer)
    }

    private func song(_ duration: TimeInterval = 95) -> ImportedAudio {
        ImportedAudio(fileName: "song-\(UUID().uuidString).m4a", title: "Morning song", duration: duration)
    }

    // MARK: - Music

    @Test func musicStartsAtThePlayheadForAsLongAsTheEditLasts() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.addMusic(song())
        let clip = try #require(viewModel.edit.music.first)
        #expect(clip.start == 10)
        #expect(clip.length == 54)
        #expect(viewModel.selectedMusicID == clip.id)
        #expect(viewModel.musicBars.first?.span == TimeSpan(start: 10, end: 64))
        #expect(scenario.toast.message == "Music added under your voice at 40%")
        viewModel.undo()
        #expect(viewModel.edit.music.isEmpty)
    }

    @Test func aShortSongPlaysOnce() async throws {
        let scenario = await makeScenario()
        scenario.viewModel.addMusic(song(12))
        #expect(scenario.viewModel.edit.music.first?.length == 12)
    }

    @Test func importingASoundFileGoesThroughTheImporter() async {
        let scenario = await makeScenario()
        let url = URL(filePath: "/tmp/song.m4a")
        await scenario.viewModel.importMusic(from: url)
        #expect(scenario.importer.importedAudio == [url])
        #expect(scenario.viewModel.edit.music.count == 1)
        scenario.importer.audio = nil
        await scenario.viewModel.importMusic(from: url)
        #expect(scenario.toast.message == "This sound file can't be added")
        #expect(scenario.viewModel.edit.music.count == 1)
    }

    @Test func trimmingTheStartSkipsTheFilesBeginning() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.addMusic(song())
        let bar = try #require(viewModel.musicBars.first)
        viewModel.resizeBar(bar, edge: .start, to: 14)
        var clip = try #require(viewModel.edit.music.first)
        #expect(clip.start == 14 && clip.offset == 4 && clip.length == 50)
        // Back past where the file starts: it stops there.
        viewModel.resizeBar(try #require(viewModel.musicBars.first), edge: .start, to: 2)
        clip = try #require(viewModel.edit.music.first)
        #expect(clip.start == 10 && clip.offset == 0)
    }

    @Test func theEndStopsAtTheFilesEnd() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMusic(song(20))
        viewModel.resizeBar(try #require(viewModel.musicBars.first), edge: .end, to: 40)
        #expect(viewModel.edit.music.first?.length == 20)
        viewModel.resizeBar(try #require(viewModel.musicBars.first), edge: .end, to: 8)
        #expect(viewModel.edit.music.first?.length == 8)
    }

    @Test func movingKeepsTheLengthWithinTheEdit() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMusic(song(20))
        viewModel.moveBar(try #require(viewModel.musicBars.first), toStart: 60)
        #expect(viewModel.edit.music.first?.start == 44)
    }

    @Test func aSliderIsOneUndoStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMusic(song())
        let id = try #require(viewModel.edit.music.first?.id)
        let steps = viewModel.history.past.count
        viewModel.beginChange()
        for volume in stride(from: 0.5, through: 0.9, by: 0.1) { viewModel.setMusicVolume(id, volume) }
        viewModel.endChange()
        #expect(viewModel.history.past.count == steps + 1)
        #expect(abs((viewModel.edit.music.first?.volume ?? 0) - 0.9) < 0.001)
        viewModel.setMusicMuted(id, true)
        viewModel.setMusicDucks(id, false)
        viewModel.setMusicFadeIn(id, 9)
        let clip = try #require(viewModel.edit.music.first)
        #expect(clip.isMuted && !clip.ducksUnderVoice && clip.fadeIn == MusicClip.fadeRange.upperBound)
    }

    @Test func musicIsOnTheSharedTimelineAndCanBeDeleted() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMusic(song())
        viewModel.clearLayerSelection()
        let bar = try #require(viewModel.musicBars.first)
        viewModel.selectBar(bar)
        #expect(viewModel.selectedLayer?.kind == .music)
        viewModel.deleteSelectedLayer()
        #expect(viewModel.edit.music.isEmpty)
    }

    // MARK: - Voice

    @Test func anOldEditMovesToTheLevelsOnlyWhenOneIsTouched() async {
        var old = TakeEdit(sourceDuration: 64, aspect: .portrait)
        old.audioVersion = 1
        old.enhancesVoice = true
        old.reducesNoise = false
        let scenario = await makeScenario(edit: old)
        let viewModel = scenario.viewModel
        #expect(viewModel.edit.audioVersion == 1)
        viewModel.setNoiseReduction(.strong)
        #expect(viewModel.edit.audioVersion == 3)
        #expect(viewModel.edit.voiceEnhancement == .soft)
        #expect(viewModel.edit.noiseReduction == .strong)
    }

    @Test func comparingPlaysTheUntreatedSoundAsLoud() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .voice
        viewModel.setVoiceEnhancement(.strong)
        viewModel.setComparesOriginal(true)
        await viewModel.comparisonTask?.value
        #expect(viewModel.comparesOriginal)
        let played = try #require(scenario.player.shown.last)
        #expect(played.voiceEnhancement == .off && played.noiseReduction == .off)
        #expect(played.volume == 1.4)
        // The edit itself keeps its treatment.
        #expect(viewModel.edit.voiceEnhancement == .strong)
        // A new setting ends the comparison.
        viewModel.setNoiseReduction(.soft)
        #expect(!viewModel.comparesOriginal)
        #expect(scenario.player.shown.last?.voiceEnhancement == .strong)
    }

    @Test func leavingVoiceEndsTheComparison() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .voice
        viewModel.setComparesOriginal(true)
        await viewModel.comparisonTask?.value
        viewModel.panel = nil
        #expect(!viewModel.comparesOriginal)
        #expect(scenario.player.shown.last == viewModel.edit)
    }

    @Test func withoutSpeechThereIsNothingToCompare() async {
        let scenario = await makeScenario()
        scenario.editor.matchedVolume = nil
        let viewModel = scenario.viewModel
        viewModel.panel = .voice
        viewModel.setComparesOriginal(true)
        await viewModel.comparisonTask?.value
        #expect(!viewModel.comparesOriginal)
        #expect(scenario.toast.message == "There's no speech to compare")
    }

    @Test func anUntreatedTakeHasNothingToCompare() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setVoiceEnhancement(.off)
        #expect(!viewModel.canCompareOriginal)
        viewModel.setComparesOriginal(true)
        #expect(!viewModel.comparesOriginal)
        #expect(scenario.editor.matchRequests == 0)
    }

    // MARK: - A video's own sound

    @Test func aVideoWithSoundAsksAndStaysMutedUntilKept() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMedia(ImportedMedia(kind: .video, fileName: "walk-\(UUID().uuidString).mov", aspect: 1, duration: 4, hasSound: true))
        let id = try #require(viewModel.edit.media.first?.id)
        #expect(viewModel.soundChoiceMediaID == id)
        #expect(viewModel.edit.media.first?.audioVolume == nil)
        viewModel.chooseSound(for: id, keeps: true)
        #expect(viewModel.soundChoiceMediaID == nil)
        #expect(viewModel.edit.media.first?.audioVolume == 1)
        viewModel.setMediaSoundVolume(id, 0)
        #expect(viewModel.edit.media.first?.audioVolume == nil)
    }

    @Test func aSilentVideoDoesNotAsk() async {
        let scenario = await makeScenario()
        scenario.viewModel.addMedia(ImportedMedia(kind: .video, fileName: "quiet-\(UUID().uuidString).mov", aspect: 1, duration: 4))
        #expect(scenario.viewModel.soundChoiceMediaID == nil)
    }
}
