//
//  OnboardingScriptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The practice script: the same for everyone, a hook, a body and a call to action, and a version that doesn't claim the text follows
/// the voice.
@Suite("OnboardingScript")
struct OnboardingScriptTests {
    @Test func thePracticeScriptIsTheOwnersFixedText() {
        let script = OnboardingScript.practice()
        #expect(script.hook == "An idea is good. Seeing it become a video is even better.")
        #expect(script.body == "Cue Studio helps me write it, read it with a teleprompter that follows my voice, and record it right here. I can add automatic captions and edit my take before sharing it.")
        #expect(script.cta == "My idea gets to sound like me and reach the people I made it for.")
        #expect(script.text == [script.hook, script.body, script.cta].joined(separator: "\n\n"))
    }

    @Test func withoutVoiceFollowingItMakesNoClaimAboutTheVoice() {
        let plain = OnboardingScript.practice(followsVoice: false)
        #expect(!plain.body.contains("voice"))
        #expect(plain.hook == OnboardingScript.practice().hook && plain.cta == OnboardingScript.practice().cta)
    }

    /// 59 words at a natural 150 a minute: 24 seconds, the time the card shows (not the board's 15).
    @Test func theReadingTimeIsMeasuredFromTheWords() {
        #expect(ReadTime.wordCount(in: OnboardingScript.practice().text) == 59)
        #expect(OnboardingScript.practice().readingSeconds == 24)
        #expect(OnboardingScript.practice(followsVoice: false).readingSeconds == 22)
    }

    @Test func newScriptCopyHasNoEmDashes() {
        for script in [OnboardingScript.practice(), OnboardingScript.practice(followsVoice: false)] {
            #expect(!script.text.contains("—") && !script.title.contains("—"))
        }
    }
}
