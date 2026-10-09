//
//  FeatureAdoptionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Used" means a result the creator kept, never a panel opened: what stops a tool's introductions.
@Suite("FeatureAdoption")
struct FeatureAdoptionTests {
    private func edit(_ change: (inout TakeEdit) -> Void = { _ in }) -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        change(&edit)
        return edit
    }

    @Test func anUntouchedEditUsedNothing() {
        #expect(FeatureAdoption.tools(in: nil).isEmpty)
        #expect(FeatureAdoption.tools(in: edit()).isEmpty)
    }

    @Test func cleanUpCountsOnceASuggestionWasDecided() {
        let span = TimeSpan(start: 1, end: 2)
        let listened = edit {
            $0.cleanUpAnalyzed = true
            $0.suggestions = [CleanUpSuggestion(kind: .pause, span: span, confidence: 1)]
        }
        #expect(!FeatureAdoption.tools(in: listened).contains(.cleanUp))
        let decided = edit {
            $0.cleanUpAnalyzed = true
            $0.suggestions = [CleanUpSuggestion(kind: .pause, span: span, confidence: 1, status: .kept)]
        }
        #expect(FeatureAdoption.tools(in: decided).contains(.cleanUp))
    }

    @Test func eachToolIsSeenInWhatItLeftInTheEdit() {
        let used = edit {
            $0.captions = [CaptionCue(text: "Hello", start: 0, end: 1)]
            $0.skinSmoothing = 20
            $0.voiceEnhancement = .strong
        }
        #expect(FeatureAdoption.tools(in: used) == [.autoCaptions, .skinSmoothing, .studioVoice])
        #expect(FeatureAdoption.tools(in: edit { $0.noiseReduction = .soft }) == [.studioVoice])
    }

    @Test func theProfileThePrompterAndTheEventsCountToo() {
        let profile = NotificationFacts.Profile(hasTopics: true, voiceConfigured: true, hasImportedWriting: false)
        let adopted = FeatureAdoption.adopted(
            takeTools: [[.covers], [.layers]], profile: profile, hasLogbookEntries: true, prompterFollowsVoice: true,
            showsSafeZone: false, events: [.remoteControl]
        )
        #expect(adopted == [.covers, .layers, .myCueVoice, .logbook, .voiceFollowing, .remoteControl])
    }
}
