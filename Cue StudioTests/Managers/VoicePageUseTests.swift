//
//  VoicePageUseTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's item 10 (02/11/2026): the page in the creator's order, and every row on it reaching the prompts (the page no longer says where,
/// the owner, 03/11/2026; the rules stay). An answer is "used" by a prompt when giving it changes that prompt.
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
    func eachRowReachesThePrompts(_ row: VoicePageRow) {
        let with = answered(row)
        // A topic: the ideas, and only the scripts about it.
        if row == .topics {
            #expect(ideas(with) != ideas(base))
            #expect(script(with, idea: "My fitness routine before work") != script(base, idea: "My fitness routine before work"), "a script about it")
            #expect(script(with, idea: "Saving for a house") == script(base, idea: "Saving for a house"), "a script about something else")
            return
        }
        // Every other row: the scripts and the ideas.
        #expect(script(with) != script(base), "scripts: \(row)")
        #expect(ideas(with) != ideas(base), "ideas: \(row)")
        // What to avoid: every tool too.
        if row == .avoid {
            #expect(VoiceBriefBuilder.restrictionLines(for: with.voice) != VoiceBriefBuilder.restrictionLines(for: base.voice), "tools: \(row)")
        }
        // The proof: never Ultra AI.
        if row == .examples || row == .stories || row == .learned {
            let ultra = { (profile: CreatorProfile) in VoiceBriefBuilder.ultraProjection(for: profile.voice, register: .casual) }
            #expect(ultra(with) == ultra(base), "Ultra AI: \(row)")
        }
    }

    @Test func thePhrasesTakeTurnsThreeAtATime() {
        let phrases = ["One", "Two", "Three", "Four", "Five"]
        #expect(CatchphraseRotation.perScript == 3)
        #expect(CatchphraseRotation.rotates(phrases))
    }

    @Test func thePageShowsEveryRowOnceInTheCreatorsOrder() {
        let rows = VoicePageSection.allCases.flatMap(\.rows)
        #expect(rows.count == VoicePageRow.allCases.count && Set(rows) == Set(VoicePageRow.allCases))
        // Who they are and what their videos are for, together (the owner, 03/11/2026).
        #expect(VoicePageSection.allCases.first?.rows == [.role, .goals])
        #expect(VoicePageSection.proof.rows == [.examples, .learned])
    }
}
