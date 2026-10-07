//
//  VoiceAdjustmentTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Adjust": what didn't sound like the creator, as small changes to the voice.
@Suite("Voice adjustment")
struct VoiceAdjustmentTests {
    private let profile = CreatorProfile(
        phrases: ["Hey fam"], sounds: [.professional, .energetic], vocabulary: .genZ, styles: [.conversational]
    )

    @Test func tooFormalDropsProfessionalForCasual() {
        let adjusted = VoiceAdjustment.tooFormal.applied(to: profile)
        #expect(!adjusted.sounds.contains(.professional) && adjusted.sounds.contains(.casual))
        var professional = profile
        professional.vocabulary = .professional
        #expect(VoiceAdjustment.tooFormal.applied(to: professional).vocabulary == .simple)
    }

    @Test func tooMuchSlangMovesGenZToSimpleAndLeavesOthersAlone() {
        #expect(VoiceAdjustment.tooMuchSlang.applied(to: profile).vocabulary == .simple)
        var technical = profile
        technical.vocabulary = .technical
        #expect(VoiceAdjustment.tooMuchSlang.applied(to: technical).vocabulary == .technical)
    }

    @Test func tooOverTheTopCalmsTheEnergyButNeverLeavesNoSound() {
        #expect(VoiceAdjustment.tooOverTheTop.applied(to: profile).sounds == [.professional])
        var loud = profile
        loud.sounds = [.funny]
        #expect(VoiceAdjustment.tooOverTheTop.applied(to: loud).sounds == [.casual])
    }

    @Test func aPhraseTheyDontSayIsRemovedAndLongSentencesGetShort() {
        #expect(VoiceAdjustment.notMyPhrase.applied(to: profile).phrases.isEmpty)
        let short = VoiceAdjustment.tooLong.applied(to: profile)
        #expect(short.styles.contains(.shortSentences))
        // Twice makes no difference.
        #expect(VoiceAdjustment.tooLong.applied(to: short).styles == short.styles)
    }

    @Test func theAdjustmentsChangeWhatThePromptReadsNotJustTheLegacyFields() {
        var voiced = profile
        voiced.style = VoiceDelivery(energy: .high, sentences: .long, words: .someSlang, swearing: .mild)
        #expect(VoiceAdjustment.tooLong.applied(to: voiced).style.sentences == .short)
        #expect(VoiceAdjustment.tooMuchSlang.applied(to: voiced).style.words == .plain)
        #expect(VoiceAdjustment.tooOverTheTop.applied(to: voiced).style.energy == .calm)
        var expert = voiced
        expert.style.words = .expertTerms
        #expect(VoiceAdjustment.tooFormal.applied(to: expert).style.words == .plain)
        // What was never answered stays unanswered: an adjustment doesn't invent an answer.
        #expect(VoiceAdjustment.tooLong.applied(to: profile).style.sentences == nil)
        #expect(VoiceAdjustment.tooOverTheTop.applied(to: profile).style.energy == nil)
    }

    @Test func severalAdjustmentsApplyOneAfterTheOther() {
        let adjusted = VoiceAdjustment.applying([.tooMuchSlang, .notMyPhrase, .tooLong], to: profile)
        #expect(adjusted.vocabulary == .simple && adjusted.phrases.isEmpty && adjusted.styles.contains(.shortSentences))
        #expect(VoiceAdjustment.applying([], to: profile) == profile)
    }

    @Test func everyAdjustmentSaysWhatItChanges() {
        for adjustment in VoiceAdjustment.allCases {
            #expect(!adjustment.label.isEmpty && !adjustment.change.isEmpty)
        }
    }
}
