//
//  CreatorVoiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("CreatorVoice")
struct CreatorVoiceTests {
    @Test func summaryShowsTwoSoundsAndTheFirstPhrase() {
        let voice = CreatorVoice(sounds: [.casual, .confident, .funny], phrases: ["Hey fam", "Real talk"], vocabulary: .simple, styles: [], niches: [])
        #expect(voice.summary == "Conversational · Confident · “Hey fam”")
    }

    @Test func sampleLineFollowsSoundStyleAndVocabulary() {
        let voice = CreatorVoice(sounds: [.energetic], phrases: ["Hey fam"], vocabulary: .genZ, styles: [.storytelling], niches: [])
        #expect(voice.sampleLine == "Hey fam! Okay, this is huge! Last week I filmed five videos in one afternoon. No cap.")
    }
}
