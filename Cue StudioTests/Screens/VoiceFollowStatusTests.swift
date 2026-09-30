//
//  VoiceFollowStatusTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Following the words is only claimed while recognition really follows them.
@MainActor
@Suite("VoiceFollowStatus")
struct VoiceFollowStatusTests {
    @Test func followingTheWordsOnlyWhileRecognitionListens() {
        #expect(VoiceFollowStatus(followsSpeech: true, preparation: nil) == .followingWords)
        #expect(VoiceFollowStatus(followsSpeech: false, preparation: .preparing) == .preparing)
        #expect(VoiceFollowStatus(followsSpeech: false, preparation: .downloading(.thai, progress: 0.4)) == .downloading(.thai, progress: 0.4))
        #expect(VoiceFollowStatus(followsSpeech: false, preparation: nil) == .scrollsWhileTalking)
    }

    @Test func theTagSaysWhoSetsThePace() {
        #expect(VoiceFollowStatus.followingWords.tag(speedLabel: "0.7×") == String(localized: "AUTO"))
        #expect(VoiceFollowStatus.scrollsWhileTalking.tag(speedLabel: "0.7×") == "0.7×")
        #expect(VoiceFollowStatus.preparing.tag(speedLabel: "0.7×") == "0.7×")
    }

    @Test func scrollingWhileTalkingNamesTheSpeed() {
        let detail = VoiceFollowStatus.scrollsWhileTalking.detail(speedLabel: "0.7×")
        #expect(detail.contains("0.7×"))
        #expect(detail != VoiceFollowStatus.followingWords.detail(speedLabel: "0.7×"))
    }

    @Test func aDownloadSaysWhichLanguageAndHowFar() {
        let status = VoiceFollowStatus.downloading(.thai, progress: 0.4)
        let detail = status.detail(speedLabel: "0.7×")
        #expect(detail.contains(CueLanguage.thai.localizedName))
        #expect(detail.contains("40"))
        #expect(status.shortLabel(isListening: true).contains("40"))
    }

    @Test func voiceOverHearsTheSameThing() {
        let status = VoiceFollowStatus.scrollsWhileTalking
        #expect(status.accessibilityValue(isListening: true, speedLabel: "0.7×") == status.detail(speedLabel: "0.7×"))
        #expect(VoiceFollowStatus.followingWords.accessibilityValue(isListening: true, speedLabel: "0.7×") == String(localized: "Listening"))
    }
}
