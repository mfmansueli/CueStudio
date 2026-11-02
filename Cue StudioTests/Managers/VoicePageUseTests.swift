//
//  VoicePageUseTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's items 2 and 10 (02/11/2026): the page in the creator's order, and each row's "where it is used" true of what the prompts carry. An
/// answer is "used" by a prompt when giving it changes that prompt.
@MainActor
struct VoicePageUseTests {
    /// Someone who said what kind of creator they are: what every row adds to.
    private var base: CreatorProfile {
        var profile = CreatorProfile()
        profile.role = .educator
        profile.confirm(.role)
        return profile
    }

    /// The profile with the row answered.
    private func answered(_ row: VoicePageRow) -> CreatorProfile {
        var profile = base
        switch row {
        case .formats, .openings, .endings, .goals, .phrases, .avoid, .reach, .notes, .stories, .examples, .learned: answerHabit(row, in: &profile)
        case .role: profile.credential = "Nurse for ten years"
        case .topics: profile.niches = [.fitness]
        case .audience:
            profile.audienceGroup = .parents
            profile.confirm(.audience)
        case .watch: profile.watchReasons = [.learn]
        case .tone:
            profile.sounds = [.dry]
            profile.confirm(.tone)
        case .style: profile.style.sentences = .short
        }
        return profile
    }

    private func answerHabit(_ row: VoicePageRow, in profile: inout CreatorProfile) {
        switch row {
        case .formats: profile.formats = [.mythFact]
        case .openings: profile.openings = ["Question"]
        case .endings: profile.endings = ["Save this"]
        case .goals: profile.contentGoals = [.sell]
        case .phrases: profile.phrases = ["Okay, real talk."]
        case .avoid: profile.avoid = ["the word hustle"]
        case .reach: profile.reach.platforms = [.tiktok]
        case .notes: profile.customTags = ["I film in my car"]
        case .stories: profile.stories = [VoiceStory(kind: .start, text: "I started filming in my car because it was the only quiet place.")]
        case .examples: profile.examples = [VoiceExample(text: "So here’s the thing. I tried it for a week and it actually stuck.")]
        case .learned:
            profile.approvedSamples = [VoiceExample(text: "Okay, quick one today. Three things I do before coffee.", source: "Sounds like me")]
        default: break
        }
    }

    private func script(_ profile: CreatorProfile, idea: String? = nil) -> String {
        VoiceBriefBuilder.brief(for: idea.map { profile.voice(inLanguage: "en", idea: $0) } ?? profile.voice).text
    }

    private func ideas(_ profile: CreatorProfile) -> String {
        ScriptPromptBuilder.themesInstructions(voice: profile.voice)
    }

    @Test(arguments: VoicePageRow.allCases)
    func eachRowSaysWhereItIsUsed(_ row: VoicePageRow) {
        let with = answered(row)
        let use = row.use
        if use == String(localized: "Ideas, and scripts about them") {
            #expect(ideas(with) != ideas(base))
            #expect(script(with, idea: "My fitness routine before work") != script(base, idea: "My fitness routine before work"), "a script about it")
            #expect(script(with, idea: "Saving for a house") == script(base, idea: "Saving for a house"), "a script about something else")
            return
        }
        // Every other row: the scripts and the ideas.
        #expect(script(with) != script(base), "scripts: \(row)")
        #expect(ideas(with) != ideas(base), "ideas: \(row)")
        if use == String(localized: "Scripts, ideas and every tool") {
            #expect(VoiceBriefBuilder.restrictionLines(for: with.voice) != VoiceBriefBuilder.restrictionLines(for: base.voice), "tools: \(row)")
        }
        if use == String(localized: "Scripts and ideas, never Ultra AI") || row == .learned {
            let ultra = { (profile: CreatorProfile) in VoiceBriefBuilder.ultraProjection(for: profile.voice, register: .casual) }
            #expect(ultra(with) == ultra(base), "Ultra AI: \(row)")
        }
    }

    @Test func thePhrasesTakeTurnsThreeAtATime() {
        let phrases = ["One", "Two", "Three", "Four", "Five"]
        #expect(VoicePageRow.phrases.use == String(localized: "Up to \(CatchphraseRotation.perScript) per script, taking turns"))
        #expect(CatchphraseRotation.perScript == 3)
        #expect(CatchphraseRotation.rotates(phrases))
    }

    @Test func thePageShowsEveryRowOnceInTheCreatorsOrder() {
        let rows = VoicePageSection.allCases.flatMap(\.rows)
        #expect(rows.count == VoicePageRow.allCases.count && Set(rows) == Set(VoicePageRow.allCases))
        #expect(VoicePageSection.allCases.first?.rows == [.role])
        #expect(VoicePageSection.proof.rows == [.examples, .learned])
    }
}
