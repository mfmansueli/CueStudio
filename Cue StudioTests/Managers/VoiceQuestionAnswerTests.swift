//
//  VoiceQuestionAnswerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// 08 §2: every question of the bank writes to the profile through one place, and answering them all reaches exactly 100.
@MainActor
@Suite("My Cue Voice question bank")
struct VoiceQuestionAnswerTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    @Test func theBankHasSeventeenQuestionsInQueueOrder() {
        #expect(VoiceQuestion.allCases.count == 17)
        #expect(VoiceQuestion.allCases.map(\.rawValue).prefix(4) == ["role", "topics", "audience", "tone"])
        #expect(VoiceQuestion.allCases.last == .example)
    }

    @Test func theAppsEightRolesAndEightTonesAreTheOptions() {
        #expect(VoiceQuestion.role.options.count == 8)
        #expect(VoiceQuestion.tone.options.map(\.label) == [
            "Conversational", "Straight to the point", "Educational", "Confident", "Warm & calm", "Energetic", "Playful", "Dry & sarcastic",
        ])
        #expect(VoiceQuestion.topics.options.count == Niche.allCases.count)
    }

    @Test func rowsWithoutFreeTextHaveNone() {
        for question in [VoiceQuestion.length, .humor, .platforms, .energy, .sentences, .words, .swearing] {
            #expect(!question.allowsSomethingElse, "\(question)")
        }
        #expect(!VoiceQuestion.swearing.allowsNone)
        #expect(VoiceQuestion.endings.allowsNone && VoiceQuestion.endings.allowsSomethingElse)
    }

    @Test func answeringEveryQuestionReachesExactlyOneHundred() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        for question in VoiceQuestion.allCases where question != .example {
            guard let option = question.options.first(where: { $0.id != VoiceQuestion.talkingHeadID }) ?? question.options.first else { continue }
            service.answer(question, with: option)
        }
        service.answerAudienceLevel(.experienced)
        #expect(service.profile.voiceStrength == 80)
        service.addExample("Okay, real talk. This is my first example. Short and mine.")
        service.addExample("Okay, real talk. This is my second example. Short and mine.")
        service.addExample("Okay, real talk. This is my third example. Short and mine.")
        #expect(service.profile.voiceStrength == 100)
    }

    @Test func aSingleAnswerReplacesAndAMultipleOneToggles() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let tiktok = VoiceOption(id: Platform.tiktok.rawValue, label: "TikTok")
        let shorts = VoiceOption(id: Platform.shorts.rawValue, label: "Shorts")
        service.answer(.platforms, with: tiktok)
        service.answer(.platforms, with: shorts)
        #expect(service.profile.reach.platforms == [.shorts])
        let food = VoiceOption(id: Niche.food.rawValue, label: "Food")
        #expect(service.answer(.topics, with: food) == .added)
        #expect(service.answer(.topics, with: food) == .removed)
    }

    @Test func topicsStopAtThreeAndTonesAtTwo() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        for niche in [Niche.food, .tech, .fitness] {
            service.answer(.topics, with: VoiceOption(id: niche.rawValue, label: niche.label))
        }
        #expect(service.answer(.topics, with: VoiceOption(id: Niche.beauty.rawValue, label: "Beauty")) == .limit("Max 3 topics"))
        service.answer(.tone, with: VoiceOption(id: VoiceSound.casual.rawValue, label: ""))
        service.answer(.tone, with: VoiceOption(id: VoiceSound.dry.rawValue, label: ""))
        #expect(service.answer(.tone, with: VoiceOption(id: VoiceSound.confident.rawValue, label: "")) == .limit("Max 2 tones"))
        #expect(service.profile.sounds == [.casual, .dry], "the defaults of a new profile never ride along")
    }

    @Test func nothingToAvoidAndAnItemExcludeEachOther() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let nothing = VoiceOption(id: VoiceQuestion.nothingToAvoidID, label: "Nothing to avoid")
        service.answer(.avoid, with: VoiceOption(id: "Politics", label: "Politics"))
        service.answer(.avoid, with: nothing)
        #expect(service.profile.avoid.isEmpty && service.profile.avoidNone)
        service.answer(.avoid, with: VoiceOption(id: "Clickbait", label: "Clickbait"))
        #expect(service.profile.avoid == ["Clickbait"] && !service.profile.avoidNone)
    }

    @Test func talkingHeadIsKeptAsATagAndCountsAsAFormat() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let option = VoiceOption(id: VoiceQuestion.talkingHeadID, label: "Talking head")
        #expect(service.answer(.formats, with: option) == .added)
        #expect(service.profile.isFilled(VoiceField.formats))
        #expect(service.isSelected(option, for: .formats))
        #expect(service.answer(.formats, with: option) == .removed)
        #expect(!service.profile.isFilled(VoiceField.formats))
    }

    @Test func somethingElseIsCheckedLikeEveryTypedAnswer() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.addSomethingElse("a", for: .tone) == .rejected(.tooShort))
        #expect(service.addSomethingElse("what the fuck", for: .avoid) == .rejected(.blocked))
        #expect(service.addSomethingElse("Slow and warm", for: .tone) == .added)
        #expect(service.profile.customTags == ["Slow and warm"])
        #expect(service.addSomethingElse("slow and warm", for: .tone) == .alreadyThere)
        #expect(service.addSomethingElse("Clickbiat", for: .avoid) == .suggest(suggestion: "Clickbait", original: "Clickbiat"))
        #expect(service.addSomethingElse("Gardening", for: .topics) == .added)
        #expect(service.profile.customTopics == ["Gardening"])
    }

    @Test func theBriefTellsTheModelWhatTheNewFieldsSay() {
        var profile = VoiceQuestionSchedulerTests.fullProfile()
        profile.avoid = ["Clickbait", "Politics"]
        let brief = ScriptPromptBuilder.voiceBrief(profile)
        #expect(brief.contains("Never write: Clickbait, Politics."))
        #expect(brief.contains("Their energy on camera is high."))
        #expect(brief.contains("They speak in mixed sentences."))
        #expect(brief.contains("Their audience is some basics."))
        #expect(brief.contains("humor in their videos: a lot"))
    }
}
