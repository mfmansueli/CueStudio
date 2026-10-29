//
//  SpokenSpansTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Who music goes down under (`SpokenSpans`): the voice in the clips whose sound is heard, each narration where it really
/// speaks (its pauses are pauses), the speech in a sound taken out of a clip; music saved before still hears what it always did.
@Suite("Spoken spans")
struct SpokenSpansTests {
    private let window = TimeSpan(start: 0, end: 10)

    private func near(_ spans: [TimeSpan], _ expected: [TimeSpan]) -> Bool {
        spans.count == expected.count && zip(spans, expected).allSatisfy { abs($0.start - $1.start) < 0.001 && abs($0.end - $1.end) < 0.001 }
    }

    @Test func aMutedClipIsNoVoice() throws {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        let split = edit.timeline.split(atEdited: 5)
        #expect(split)
        var second = try #require(edit.timeline.segments.last)
        second.isMuted = true
        let replaced = edit.timeline.replaceSegment(second)
        #expect(replaced)
        let speech = VoiceActivity(take: [TimeSpan(start: 1, end: 3), TimeSpan(start: 6, end: 8)])
        let spoken = SpokenSpans(edit: edit, speech: speech, window: window)
        #expect(near(spoken.spans, [TimeSpan(start: 1, end: 3)]))
        // Music saved before goes down under it still, as it always did.
        #expect(near(spoken.legacySpans, [TimeSpan(start: 1, end: 3), TimeSpan(start: 6, end: 8)]))
    }

    @Test func aNarrationCountsWhereItSpeaks() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var clip = VoiceOverClip(fileName: "narration.m4a", duration: 6, anchor: 2)
        // Its first second trimmed: it plays the file from 1 s at 2 s of the edit, for 5 s.
        clip.offset = 1
        edit.voiceOvers = [clip]
        var speech = VoiceActivity()
        speech.files["narration.m4a"] = [TimeSpan(start: 0.5, end: 2), TimeSpan(start: 4, end: 5.5)]
        let spoken = SpokenSpans(edit: edit, speech: speech, window: window)
        #expect(near(spoken.spans, [TimeSpan(start: 2, end: 3), TimeSpan(start: 5, end: 6.5)]))
        #expect(near(spoken.legacySpans, [TimeSpan(start: 2, end: 7)]))
        // Its speech not known: the whole of it.
        #expect(near(SpokenSpans(edit: edit, speech: VoiceActivity(), window: window).spans, [TimeSpan(start: 2, end: 7)]))
        // Turned all the way down: nobody speaks.
        edit.voiceOvers[0].volume = 0
        #expect(SpokenSpans(edit: edit, speech: speech, window: window).spans.isEmpty)
    }

    @Test func aSoundTakenOutOfAClipSpeaksWhereItPlays() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var extracted = MusicClip(fileName: "taken.m4a", title: "Clip 1", fileDuration: 10, start: 3, length: 4)
        extracted.extractedFrom = .clip
        extracted.offset = 1
        edit.music = [extracted]
        var speech = VoiceActivity()
        speech.files["taken.m4a"] = [TimeSpan(start: 2, end: 3)]
        let spoken = SpokenSpans(edit: edit, speech: speech, window: window)
        // File 2–3 s, played from 1 s at 3 s: 4–5 s of the edit.
        #expect(near(spoken.spans, [TimeSpan(start: 4, end: 5)]))
    }
}
