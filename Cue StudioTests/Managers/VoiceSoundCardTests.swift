//
//  VoiceSoundCardTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One "How you sound" card (the owner's item 4, 02/11/2026): five tones, the four controls, and one example that changes with each tap.
struct VoiceSoundCardTests {
    @Test func theCardOffersTheFiveTonesOnlyATonesSays() {
        #expect(VoiceSound.offered == [.casual, .professional, .educational, .confident, .dry])
    }

    @Test func theExampleChangesWithEveryControl() {
        var profile = CreatorProfile()
        var seen = [VoiceSampleBuilder.soundExample(for: profile)]
        profile.sounds = [.dry]
        profile.confirm(.tone)
        seen.append(VoiceSampleBuilder.soundExample(for: profile))
        for energy in VoiceEnergy.allCases {
            profile.style.energy = energy
            seen.append(VoiceSampleBuilder.soundExample(for: profile))
        }
        // Short sentences and plain words are what the example starts with, so they come last.
        for sentences in [SentenceLength.mixed, .long, .short] {
            profile.style.sentences = sentences
            seen.append(VoiceSampleBuilder.soundExample(for: profile))
        }
        for words in [WordLevel.expertTerms, .someSlang, .plain] {
            profile.style.words = words
            seen.append(VoiceSampleBuilder.soundExample(for: profile))
        }
        profile.reach.humor = .lot
        seen.append(VoiceSampleBuilder.soundExample(for: profile))
        // Each tap gives a line the previous one wasn't (the last value of a control is where the next control starts from).
        for (previous, next) in zip(seen, seen.dropFirst()) where previous == next {
            Issue.record("a tap left the example as it was: \(next)")
        }
    }

    @Test func anOlderToneBecomesEnergyOrHumor() throws {
        let saved = #"{"sounds":["warmCalm","funny","dry"],"confirmedVoiceSteps":["tone"]}"#
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(saved.utf8))
        #expect(profile.sounds == [.dry])
        #expect(profile.style.energy == .calm)
        #expect(profile.reach.humor == .little)
        var answered = CreatorProfile()
        answered.sounds = [.energetic]
        answered.style.energy = .balanced
        answered.foldTones()
        #expect(answered.sounds.isEmpty && answered.style.energy == .balanced, "what they answered stays")
    }
}
