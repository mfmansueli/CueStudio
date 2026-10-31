//
//  VoiceStrengthLevelTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Decision 8: the voice meter counts what was filled in, so its top never says "Sounds like you": "Profile 85% filled", and "Profile
/// complete" only at 100%.
@Suite("Voice strength level")
struct VoiceStrengthLevelTests {
    @Test func theTopSaysHowMuchIsFilled() {
        #expect(VoiceStrengthLevel(strength: 84).label == "Good start")
        #expect(VoiceStrengthLevel(strength: 85).label == "Profile 85% filled")
        #expect(VoiceStrengthLevel(strength: 99).label == "Profile 99% filled")
        #expect(VoiceStrengthLevel(strength: 100).label == "Profile complete")
        #expect(VoiceStrengthLevel(strength: 10).label == "Just started")
    }
}
