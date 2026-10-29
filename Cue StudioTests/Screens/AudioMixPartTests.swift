//
//  AudioMixPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Phase 8's sound in the editor (`AudioViewModel`): music lowered under the voice by its own settings (a clip saved before
/// moves to them only when touched; every music clip at once in one undo step; ◐ plays one clip without lowering), Voice
/// effects on a clip or a voice-over (None goes back to the voice as it was; ◐ plays it without), and a spoken narration added
/// at the playhead or replacing one in place.
@MainActor
@Suite("Audio mix part")
struct AudioMixPartTests {
    let host: FakeEditorHost
    let part: AudioViewModel

    init() {
        host = FakeEditorHost(edit: TakeEdit(sourceDuration: 20, aspect: .portrait))
        part = AudioViewModel(
            session: host.session, editing: FakeTakeEditor(), importer: FakeMediaImporter(), recorder: FakeVoiceRecorder(),
            editorPreferences: FakeEditorPreferencesStore(), prompterLook: PrompterSettings(), soundPreviews: SoundPreviewPlayer(),
            narrationSpeaker: FakeNarrationSpeaker()
        )
    }

    private func music(_ title: String, start: TimeInterval = 0) -> MusicClip {
        MusicClip(fileName: "\(title).m4a", title: title, fileDuration: 30, start: start, length: 10)
    }

    // MARK: - Lowering under the voice

    @Test func aClipSavedBeforeMovesToTheSettingsWhenTouched() throws {
        let saved = music("Saved")
        host.document.change(key: nil) { $0.music = [saved] }
        #expect(host.document.edit.music[0].duck == nil)
        part.setMusicDuckDepth(saved.id, 20.4)
        #expect(host.document.edit.music[0].duck == MusicDuck(depth: 20, pauses: .staysLow))
        part.setMusicDuckPauses(saved.id, .comesBack)
        #expect(host.document.edit.music[0].duck == MusicDuck(depth: 20, pauses: .comesBack))
        // Turned off and on, it keeps its settings.
        part.setMusicDucks(saved.id, false)
        part.setMusicDucks(saved.id, true)
        #expect(host.document.edit.music[0].duck == MusicDuck(depth: 20, pauses: .comesBack))
    }

    @Test func everyMusicClipLowersAlikeInOneUndoStep() throws {
        var first = music("First"), second = music("Second", start: 10)
        first.duck = MusicDuck(depth: 24, pauses: .comesBack)
        second.ducksUnderVoice = false
        var effect = MusicClip(fileName: "pop.caf", title: "Pop", fileDuration: 0.5, start: 2, length: 0.5)
        effect.effect = .pop
        effect.ducksUnderVoice = false
        host.document.change(key: nil) { $0.music = [first, second, effect] }
        let steps = host.document.history.past.count
        #expect(part.musicLoweringDifferently(from: first) == 1)
        part.useLoweringOnAllMusic(from: first.id)
        let edited = host.document.edit.music
        #expect(edited[1].ducksUnderVoice && edited[1].duck == first.duck)
        // A sound effect isn't music: it stays as it was.
        #expect(!edited[2].ducksUnderVoice && edited[2].duck == nil)
        #expect(host.document.history.past.count == steps + 1)
        #expect(part.musicLoweringDifferently(from: edited[0]) == 0)
    }

    @Test func compareplaysOneClipWithoutLoweringUntilThePanelCloses() throws {
        let first = music("First"), second = music("Second", start: 10)
        host.document.change(key: nil) { $0.music = [first, second] }
        let shown = host.playedEditShown
        part.duckingCompare(for: first).show(true)
        let played = part.withoutComparedDucking(host.document.edit)
        #expect(!played.music[0].ducksUnderVoice)
        #expect(played.music[1].ducksUnderVoice)
        #expect(host.playedEditShown > shown)
        part.panelChanged(from: .volume)
        #expect(part.comparedDuckingID == nil)
        #expect(part.withoutComparedDucking(host.document.edit) == host.document.edit)
    }

    // MARK: - Voice effects

    @Test func aVoiceOverTakesAnEffectAndGoesBackToItsVoice() throws {
        let clip = VoiceOverClip(fileName: "voice.m4a", duration: 4, anchor: 2)
        host.document.change(key: nil) { $0.voiceOvers = [clip] }
        host.selection = .voiceOver(clip.id)
        #expect(part.voiceEffectTarget == .voiceOver(clip.id))
        part.setVoiceEffect(.robot)
        #expect(host.document.edit.voiceOvers[0].voiceEffect == VoiceEffectSetting(effect: .robot))
        part.setVoiceEffectAmount(0.33)
        #expect(host.document.edit.voiceOvers[0].voiceEffect?.amount == 0.35)
        // Another effect keeps the amount.
        part.setVoiceEffect(.radio)
        #expect(host.document.edit.voiceOvers[0].voiceEffect == VoiceEffectSetting(effect: .radio, amount: 0.35))
        // ◐ plays it without.
        part.voiceEffectCompare.show(true)
        #expect(part.withoutComparedVoiceEffect(host.document.edit).voiceOvers[0].voiceEffect == nil)
        part.panelChanged(from: .voiceEffects)
        #expect(part.comparedVoiceEffect == nil)
        part.setVoiceEffect(nil)
        #expect(host.document.edit.voiceOvers[0].voiceEffect == nil)
    }

    @Test func aClipTakesAnEffectOnItsOwn() throws {
        var timeline = host.document.edit.timeline
        let split = timeline.split(atEdited: 8)
        #expect(split)
        host.document.change(key: nil) { $0.timeline = timeline }
        let second = try #require(host.document.edit.timeline.segments.last)
        host.selection = .clip(second.id)
        part.setVoiceEffect(.deep)
        #expect(host.document.edit.timeline.segments.last?.voiceEffect?.effect == .deep)
        #expect(host.document.edit.timeline.segments.first?.voiceEffect == nil)
        // A muted clip has no voice to change.
        var muted = try #require(host.document.edit.timeline.segments.last)
        muted.isMuted = true
        var mutedTimeline = host.document.edit.timeline
        mutedTimeline.replaceSegment(muted)
        host.document.change(key: nil) { $0.timeline = mutedTimeline }
        #expect(!part.voiceEffectIsHeard)
    }

    // MARK: - Music library

    @Test func aLibraryTrackGoesInWithItsOriginBeatsAndLowering() async throws {
        let files = FakeMusicLibraryFiles()
        let library = AudioViewModel(
            session: host.session, editing: FakeTakeEditor(), importer: FakeMediaImporter(), recorder: FakeVoiceRecorder(),
            editorPreferences: FakeEditorPreferencesStore(), prompterLook: PrompterSettings(), soundPreviews: FakeSoundPreviews(),
            narrationSpeaker: FakeNarrationSpeaker(), musicFiles: files
        )
        defer {
            EditMediaFiles.remove(Set(host.document.edit.music.map(\.fileName)))
            files.removeAll()
        }
        let added = await library.addLibraryTrack(.cleanSlate)
        #expect(added)
        let clip = try #require(host.document.edit.music.first)
        #expect(clip.libraryTrack == .cleanSlate && clip.title == "Clean Slate")
        #expect(clip.duck == .standard && clip.volume == AudioViewModel.newMusicVolume)
        // Its beats are the manifest's (kept to the millisecond), ready without looking for them.
        let beats = try #require(BeatStore.load(forSound: clip.fileName))
        #expect(beats.tempo == CueTrack.cleanSlate.tempo)
        #expect(beats.beats == CueTrack.cleanSlate.beats.map { ($0 * 1000).rounded() / 1000 })
        try? FileManager.default.removeItem(at: BeatStore.url(forSound: clip.fileName))
        // Replace puts another track in the same clip, with its own origin.
        library.musicReplacementID = clip.id
        let replaced = await library.addLibraryTrack(.slowTide)
        #expect(replaced)
        #expect(host.document.edit.music.count == 1 && host.document.edit.music[0].libraryTrack == .slowTide)
        #expect(host.document.edit.music[0].id == clip.id)
        try? FileManager.default.removeItem(at: BeatStore.url(forSound: host.document.edit.music[0].fileName))
    }

    @Test func aLibraryTrackSurvivesSavingAndReopening() throws {
        var clip = music("Morning Notes")
        clip.libraryTrack = .morningNotes
        clip.duck = MusicDuck(depth: 18, pauses: .comesBack)
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.music = [clip]
        var voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)
        voice.voiceEffect = VoiceEffectSetting(effect: .hall, amount: 0.4)
        voice.spoken = SpokenNarration(text: "Olá", voiceID: "pt.felipe", language: "pt-BR", speed: 1.25)
        edit.voiceOvers = [voice]
        var segment = try #require(edit.timeline.segments.first)
        segment.voiceEffect = VoiceEffectSetting(effect: .megaphone)
        _ = edit.timeline.replaceSegment(segment)
        let reopened = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(reopened.music == edit.music)
        #expect(reopened.voiceOvers == edit.voiceOvers)
        #expect(reopened.timeline.segments.first?.voiceEffect == VoiceEffectSetting(effect: .megaphone))
    }

    // MARK: - Text to speech

    @Test func aSpokenNarrationIsAddedAtThePlayhead() throws {
        host.session.player.seek(to: 5)
        let narration = SpokenNarration(text: "Olá", voiceID: "pt.felipe", language: "pt-BR")
        part.addSpoken(narration, fileName: "spoken.m4a", duration: 2)
        let clip = try #require(host.document.edit.voiceOvers.first)
        #expect(clip.spoken == narration)
        #expect(clip.editedSpan(in: host.document.edit.timeline)?.start == 5)
        #expect(host.selection == .voiceOver(clip.id))
    }

    @Test func replacingKeepsItsPlaceVolumeAndEffect() throws {
        var clip = VoiceOverClip(fileName: "first.m4a", duration: 3, anchor: 4)
        clip.volume = 0.6
        clip.offset = 0.5
        clip.voiceEffect = VoiceEffectSetting(effect: .echo)
        clip.spoken = SpokenNarration(text: "Antes", voiceID: "pt.felipe", language: "pt-BR")
        host.document.change(key: nil) { $0.voiceOvers = [clip] }
        part.spokenReplacementID = clip.id
        let narration = SpokenNarration(text: "Depois", voiceID: "pt.luciana", language: "pt-BR", speed: 1.25)
        part.addSpoken(narration, fileName: "second.m4a", duration: 2.4)
        let replaced = try #require(host.document.edit.voiceOvers.first)
        #expect(host.document.edit.voiceOvers.count == 1)
        #expect(replaced.id == clip.id && replaced.anchor == 4 && replaced.volume == 0.6)
        #expect(replaced.voiceEffect == clip.voiceEffect)
        #expect(replaced.fileName == "second.m4a" && replaced.duration == 2.4 && replaced.offset == nil)
        #expect(replaced.spoken == narration)
        #expect(part.spokenReplacementID == nil)
    }
}
