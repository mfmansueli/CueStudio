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
        for cause in TooLongCause.allCases {
            #expect(!cause.label.isEmpty && !VoiceAdjustment.tooLong.change(cause: cause).isEmpty)
        }
        // Each answer says its own change; the others don't change with it.
        #expect(Set(TooLongCause.allCases.map { VoiceAdjustment.tooLong.change(cause: $0) }).count == TooLongCause.allCases.count)
        #expect(VoiceAdjustment.tooLong.change(cause: .sentences) == VoiceAdjustment.tooLong.change)
        #expect(VoiceAdjustment.tooFormal.change(cause: .video) == VoiceAdjustment.tooFormal.change)
    }

    // MARK: - What was too long

    private var voiced: CreatorProfile {
        var voiced = profile
        voiced.style = VoiceDelivery(energy: .calm, sentences: .long, words: .plain, swearing: .never)
        voiced.reach = VoiceReach(platforms: [.tiktok], length: .oneToThree, humor: .little)
        return voiced
    }

    @Test func longSentencesMakeTheSentencesShortAndNothingElse() {
        let adjusted = VoiceAdjustment.tooLong.applied(to: voiced, cause: .sentences, scriptSeconds: 90)
        #expect(adjusted.style.sentences == .short && adjusted.styles.contains(.shortSentences))
        #expect(adjusted.reach == voiced.reach && !adjusted.style.oneIdea)
    }

    @Test func aLongVideoMakesTheUsualLengthOneStepShorterAndNothingElse() {
        let adjusted = VoiceAdjustment.tooLong.applied(to: voiced, cause: .video, scriptSeconds: 90)
        #expect(adjusted.reach.length == .thirtyToSixty)
        #expect(adjusted.style == voiced.style && adjusted.styles == voiced.styles)
        // One step each time, never below the shortest.
        #expect(VideoLength.longer.shorter == .oneToThree && VideoLength.thirtyToSixty.shorter == .under30 && VideoLength.under30.shorter == .under30)
        // A usual length never answered steps down from how long this script runs.
        var unanswered = voiced
        unanswered.reach.length = nil
        #expect(VoiceAdjustment.tooLong.applied(to: unanswered, cause: .video, scriptSeconds: 75).reach.length == .thirtyToSixty)
        #expect(VoiceAdjustment.tooLong.applied(to: unanswered, cause: .video, scriptSeconds: 45).reach.length == .under30)
        #expect(VoiceAdjustment.tooLong.applied(to: unanswered, cause: .video, scriptSeconds: 240).reach.length == .oneToThree)
        #expect(VoiceAdjustment.tooLong.applied(to: unanswered, cause: .video).reach.length == nil)
    }

    @Test func aLongVideoMeansAShorterRangeOnAuto() {
        // What the factory aims Auto at (`ScriptRequestFactory.targetRange`): the usual length's range, above the spoken floor.
        #expect(VideoLength.oneToThree.targetRange == 60...180)
        #expect(VideoLength.thirtyToSixty.targetRange == 30...60)
    }

    @Test func tooManyIdeasKeepsOneIdeaPerVideoAndNothingElse() {
        let adjusted = VoiceAdjustment.tooLong.applied(to: voiced, cause: .ideas, scriptSeconds: 90)
        #expect(adjusted.style.oneIdea)
        var expected = voiced
        expected.style.oneIdea = true
        #expect(adjusted == expected)
    }

    @Test func theAnswerOnlyChangesTooLong() {
        #expect(VoiceAdjustment.tooFormal.applied(to: voiced, cause: .ideas) == VoiceAdjustment.tooFormal.applied(to: voiced))
        let both = VoiceAdjustment.applying([.tooMuchSlang, .tooLong], to: voiced, cause: .video, scriptSeconds: 90)
        #expect(both.reach.length == .thirtyToSixty && both.style.sentences == .long)
    }
}
