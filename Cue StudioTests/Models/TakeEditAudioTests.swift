//
//  TakeEditAudioTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The sound in the recipe: edits saved before the levels keep their first treatment, new ones use
/// the levels, and music and a video's own sound come back from a saved edit.
@Suite("TakeEdit audio")
struct TakeEditAudioTests {
    @Test func anEditFromBeforeTheLevelsKeepsItsFirstTreatment() throws {
        let json = """
        {"sourceDuration": 30, "trimStart": 0, "trimEnd": 30, "splits": [], "removed": [],
         "volume": 1, "enhancesVoice": true, "reducesNoise": true, "aspect": "9:16"}
        """
        let edit = try JSONDecoder().decode(TakeEdit.self, from: Data(json.utf8))
        #expect(edit.audioVersion == 1)
        #expect(edit.voiceProcessing.version == 1)
        #expect(edit.voiceProcessing.isNeeded)
        // Moving it to the levels starts from what it had.
        #expect(edit.voiceEnhancement == .soft)
        #expect(edit.noiseReduction == .soft)
        #expect(edit.music.isEmpty)
    }

    @Test func aNewEditUsesTheLevels() {
        let edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        #expect(edit.audioVersion == 2)
        #expect(edit.voiceEnhancement == .soft)
        #expect(edit.noiseReduction == .off)
        #expect(edit.voiceProcessing.isNeeded)
    }

    @Test func musicAndAVideosSoundComeBackFromASavedEdit() throws {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        edit.voiceEnhancement = .strong
        edit.noiseReduction = .soft
        var clip = MusicClip(fileName: "song.m4a", title: "Song", fileDuration: 120, start: 2, length: 20)
        clip.volume = 0.3
        clip.ducksUnderVoice = false
        edit.music = [clip]
        var video = MediaOverlay(kind: .video, fileName: "walk.mov", aspect: 1, mediaDuration: 4, span: TimeSpan(start: 1, end: 5))
        video.hasSound = true
        video.audioVolume = 0.6
        edit.media = [video]
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(decoded.audioVersion == 2)
        #expect(decoded.voiceEnhancement == .strong)
        #expect(decoded.noiseReduction == .soft)
        #expect(decoded.music == [clip])
        #expect(decoded.media.first?.audioVolume == 0.6)
        #expect(decoded.mediaFileNames.contains("song.m4a"))
        #expect(!decoded.ducksMusic)
    }

    @Test func musicPlaysOnlyWithinTheEdit() {
        let clip = MusicClip(fileName: "song.m4a", title: "Song", fileDuration: 60, start: 8, length: 30)
        #expect(clip.span(inEditOf: 20) == TimeSpan(start: 8, end: 20))
        #expect(clip.span(inEditOf: 8) == nil)
        // Never longer than the file.
        #expect(MusicClip(fileName: "a", title: "a", fileDuration: 5, start: 0, length: 9).length == 5)
    }
}
