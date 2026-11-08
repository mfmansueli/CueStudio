//
//  MusicLevelsTextTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The music's level said in one unit (E4 audio, owner 07/11/2026): percents of its own file, as Volume's slider, while someone
/// talks and in the pauses; the same words in Volume and in a kit's Editing.
@MainActor
struct MusicLevelsTextTests {
    @Test func theLevelUnderTheVoiceIsThePercentTheSliderWouldShow() {
        #expect(AudioViewModel.musicLevels(volume: 0.4, duck: .standard) == "While you talk and in pauses: 10%")
        #expect(AudioViewModel.musicLevels(volume: 0.4, duck: MusicDuck(depth: 12, pauses: .comesBack)) == "While you talk: 10% · in pauses: 40%")
        #expect(AudioViewModel.musicLevels(volume: 1, duck: MusicDuck(depth: 6, pauses: .comesBack)) == "While you talk: 50% · in pauses: 100%")
        // Very low still reads as something, never "0%" while it plays.
        #expect(AudioViewModel.musicLevels(volume: 0.05, duck: MusicDuck(depth: 30, pauses: .staysLow)) == "While you talk and in pauses: 1%")
        #expect(AudioViewModel.musicLevels(volume: 0.4, duck: nil) == nil)
    }

    @Test func aKitSaysItInTheSameWords() {
        // A video without music: the level new music would get, 40% and 12 dB down, staying low.
        let editing = BrandKitEditing(of: TakeEdit(sourceDuration: 10, aspect: .portrait))
        #expect(BrandViewModel.said(editing).music == "Music you add: 40% · While you talk and in pauses: 10%")
    }
}
