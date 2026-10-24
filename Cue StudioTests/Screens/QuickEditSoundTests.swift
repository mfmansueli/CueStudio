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
        viewModel.audio.addMusic(song())
        let clip = try #require(viewModel.edit.music.first)
        #expect(clip.start == 10)
        #expect(clip.length == 54)
        #expect(viewModel.selectedMusicID == clip.id)
        #expect(viewModel.audio.musicBars.first?.span == TimeSpan(start: 10, end: 64))
        #expect(scenario.toast.message == "Music added at \(DurationText.editor(10)) · 40%")
        #expect(scenario.toast.action?.title == "Undo")
        viewModel.undo()
        #expect(viewModel.edit.music.isEmpty)
    }

    @Test func aShortSongPlaysOnce() async throws {
        let scenario = await makeScenario()
        scenario.viewModel.audio.addMusic(song(12))
        #expect(scenario.viewModel.edit.music.first?.length == 12)
    }

    @Test func aSecondSongGoesAfterTheFirstInsteadOfOnTopOfIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.addMusic(song(20))
        scenario.player.currentTime = 5
        viewModel.audio.addMusic(song(20))
        let second = try #require(viewModel.edit.music.last)
        #expect(viewModel.edit.music.count == 2)
        #expect(second.start == 20)
        #expect(second.length == 20)
    }

    @Test func withNoFreeRoomAtThePlayheadNothingIsAdded() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.addMusic(song(95))
        scenario.player.currentTime = 30
        viewModel.audio.addMusic(song())
        #expect(viewModel.edit.music.count == 1)
        #expect(scenario.toast.message == "No room · Move the playhead")
    }

    @Test func replaceKeepsThePlaceVolumeAndFadesOfTheClip() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.audio.addMusic(song())
        let original = try #require(viewModel.edit.music.first)
        viewModel.selection = .music(original.id)
        viewModel.clips.setTargetVolume(0.8)
        viewModel.audio.musicReplacementID = original.id
        let other = ImportedAudio(fileName: "other.m4a", title: "Other loop", duration: 30)
        viewModel.audio.addMusic(other)
        let clip = try #require(viewModel.edit.music.first)
        #expect(viewModel.edit.music.count == 1)
        #expect(clip.id == original.id)
        #expect(clip.title == "Other loop" && clip.fileName == "other.m4a")
        #expect(clip.start == 10 && clip.length == 30 && clip.offset == 0)
        #expect(abs(clip.volume - 0.8) < 0.001)
        #expect(viewModel.audio.musicReplacementID == nil)
        viewModel.undo()
        #expect(viewModel.edit.music.first?.title == "Morning song")
    }

    @Test func importingASoundFileGoesThroughTheImporter() async {
        let scenario = await makeScenario()
        let url = URL(filePath: "/tmp/song.m4a")
        await scenario.viewModel.audio.importMusic(from: url)
        #expect(scenario.importer.importedAudio == [url])
        #expect(scenario.viewModel.edit.music.count == 1)
        scenario.importer.audio = nil
        await scenario.viewModel.audio.importMusic(from: url)
        #expect(scenario.toast.message == "Can't add this file")
        #expect(scenario.viewModel.edit.music.count == 1)
    }

    @Test func trimmingTheStartSkipsTheFilesBeginning() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.audio.addMusic(song())
        let bar = try #require(viewModel.audio.musicBars.first)
        viewModel.resizeBar(bar, edge: .start, to: 14)
        var clip = try #require(viewModel.edit.music.first)
        #expect(clip.start == 14 && clip.offset == 4 && clip.length == 50)
        // Back past where the file starts: it stops there.
        viewModel.resizeBar(try #require(viewModel.audio.musicBars.first), edge: .start, to: 2)
        clip = try #require(viewModel.edit.music.first)
        #expect(clip.start == 10 && clip.offset == 0)
    }

    @Test func theEndStopsAtTheFilesEnd() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.addMusic(song(20))
        viewModel.resizeBar(try #require(viewModel.audio.musicBars.first), edge: .end, to: 40)
        #expect(viewModel.edit.music.first?.length == 20)
        viewModel.resizeBar(try #require(viewModel.audio.musicBars.first), edge: .end, to: 8)
        #expect(viewModel.edit.music.first?.length == 8)
    }

    @Test func movingKeepsTheLengthWithinTheEdit() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.addMusic(song(20))
        viewModel.moveBar(try #require(viewModel.audio.musicBars.first), toStart: 60)
        #expect(viewModel.edit.music.first?.start == 44)
    }

    @Test func aSliderIsOneUndoStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.addMusic(song())
        let id = try #require(viewModel.edit.music.first?.id)
        viewModel.selection = .music(id)
        let steps = viewModel.document.history.past.count
        viewModel.beginChange()
        for volume in stride(from: 0.5, through: 0.9, by: 0.1) { viewModel.clips.setTargetVolume(volume) }
        viewModel.endChange()
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(abs((viewModel.edit.music.first?.volume ?? 0) - 0.9) < 0.001)
        #expect(abs(viewModel.clips.targetVolume - 0.9) < 0.001)
        // Volume never goes past 200%.
        viewModel.clips.setTargetVolume(5)
        #expect(viewModel.edit.music.first?.volume == 2)
        viewModel.audio.setMusicDucks(id, false)
        viewModel.audio.setMusicFadeIn(id, 9)
        let clip = try #require(viewModel.edit.music.first)
        #expect(!clip.ducksUnderVoice && clip.fadeIn == MusicClip.fadeRange.upperBound)
    }

    @Test func musicIsOnTheSharedTimelineAndCanBeDeleted() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.addMusic(song())
        viewModel.selection = nil
        let bar = try #require(viewModel.audio.musicBars.first)
        viewModel.tapTimeline(.item(.music, bar.id))
        #expect(viewModel.selectedLayer?.kind == .music)
        viewModel.perform(.deleteMusic)
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
        viewModel.audio.setNoiseReduction(.strong)
        #expect(viewModel.edit.audioVersion == 3)
        #expect(viewModel.edit.voiceEnhancement == .soft)
        #expect(viewModel.edit.noiseReduction == .strong)
    }

    @Test func comparingPlaysTheUntreatedSoundAsLoud() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .voice
        viewModel.audio.setVoiceEnhancement(.strong)
        viewModel.audio.setComparesOriginal(true)
        await viewModel.jobs.finished(.comparison)
        #expect(viewModel.audio.comparesOriginal)
        let played = try #require(scenario.player.shown.last)
        #expect(played.voiceEnhancement == .off && played.noiseReduction == .off)
        #expect(played.volume == 1.4)
        // The edit itself keeps its treatment.
        #expect(viewModel.edit.voiceEnhancement == .strong)
        // A new setting ends the comparison.
        viewModel.audio.setNoiseReduction(.soft)
        #expect(!viewModel.audio.comparesOriginal)
        #expect(scenario.player.shown.last?.voiceEnhancement == .strong)
    }

    @Test func leavingVoiceEndsTheComparison() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .voice
        viewModel.audio.setComparesOriginal(true)
        await viewModel.jobs.finished(.comparison)
        viewModel.panel = nil
        #expect(!viewModel.audio.comparesOriginal)
        #expect(scenario.player.shown.last == viewModel.edit)
    }

    @Test func withoutSpeechThereIsNothingToCompare() async {
        let scenario = await makeScenario()
        scenario.editor.matchedVolume = nil
        let viewModel = scenario.viewModel
        viewModel.panel = .voice
        viewModel.audio.setComparesOriginal(true)
        await viewModel.jobs.finished(.comparison)
        #expect(!viewModel.audio.comparesOriginal)
        #expect(scenario.toast.message == "There's no speech to compare")
    }

    @Test func anUntreatedTakeHasNothingToCompare() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.audio.setVoiceEnhancement(.off)
        #expect(!viewModel.audio.canCompareOriginal)
        viewModel.audio.setComparesOriginal(true)
        #expect(!viewModel.audio.comparesOriginal)
        #expect(scenario.editor.matchRequests == 0)
    }

    // MARK: - A video's own sound

    @Test func aVideoWithSoundAsksAndStaysMutedUntilKept() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.overlays.addMedia(ImportedMedia(kind: .video, fileName: "walk-\(UUID().uuidString).mov", aspect: 1, duration: 4, hasSound: true))
        let id = try #require(viewModel.edit.media.first?.id)
        #expect(viewModel.overlays.soundChoiceMediaID == id)
        #expect(viewModel.edit.media.first?.audioVolume == nil)
        viewModel.overlays.chooseSound(for: id, keeps: true)
        #expect(viewModel.overlays.soundChoiceMediaID == nil)
        #expect(viewModel.edit.media.first?.audioVolume == 1)
        viewModel.overlays.setMediaSoundVolume(id, 0)
        #expect(viewModel.edit.media.first?.audioVolume == nil)
    }

    @Test func aSilentVideoDoesNotAsk() async {
        let scenario = await makeScenario()
        scenario.viewModel.overlays.addMedia(ImportedMedia(kind: .video, fileName: "quiet-\(UUID().uuidString).mov", aspect: 1, duration: 4))
        #expect(scenario.viewModel.overlays.soundChoiceMediaID == nil)
    }
}
