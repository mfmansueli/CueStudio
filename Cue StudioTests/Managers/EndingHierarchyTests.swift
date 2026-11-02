//
//  EndingHierarchyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// How a script ends, in the owner's order (B1 and B11, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11, A8): this video's
/// request, then a "never" (Avoid › Calls to action), then the ending the creator usually uses, then the platform. Measured on an iPhone 15 Pro
/// before this (01/11/2026): the request of `en-no-cta` pushed for a call to action three times (the platform's line, the "CTA" block, "CTA: one
/// clear action") against one "leaving out any call to action", and 5 of 9 scripts asked for something anyway.
@MainActor
struct EndingHierarchyTests {
    private func voice(endings: [String] = [], avoid: [String] = []) -> CreatorVoice {
        var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [])
        voice.endings = endings
        voice.avoid = avoid
        return voice
    }

    private func request(
        _ idea: String = "Why to-do lists make you less productive", voice: CreatorVoice?, on route: AIModelRoute = .onDevice
    ) -> ScriptRequest {
        var request = ScriptRequest(source: .prompt(idea), platform: .tiktok, voice: voice, targetRange: 30...60, language: .english)
        request.durationPolicy = .informative
        return AIRequestPolicy.prepare(request, on: route)
    }

    private func whole(_ request: ScriptRequest) -> String {
        ScriptPromptBuilder.instructions(for: request) + "\n" + ScriptPromptBuilder.prompt(for: request)
    }

    // MARK: - The platform's ending gives way

    @Test func everyPlatformLineLosesItsEndingWhenTheCreatorDecidesIt() {
        let endings = [
            "end with one easy action", "asks to save or share", "loops back to the first", "pointing to the next video",
            "invites discussion", "request for a reply or a vote",
        ]
        for platform in Platform.allCases {
            let theirs = PlatformGuide.line(for: platform, creatorEnds: true)
            #expect(!endings.contains { theirs.contains($0) }, "\(platform): \(theirs)")
            #expect(theirs.hasSuffix(".") && !theirs.hasSuffix("..") && theirs.count < PlatformGuide.line(for: platform).count)
        }
    }

    // MARK: - "No call to action" as the habit

    @Test func theNoCallToActionCaseIsNoLongerPushedTowardsOne() {
        let text = whole(request(voice: voice(endings: ["No call to action"])))
        #expect(!text.contains("end with one easy action"), "the platform's ending")
        #expect(!text.contains("CTA"), "the block and its \"one clear action\": \(text)")
        #expect(text.contains("Close: finish on the point itself, in a line worth remembering, with no request to the viewer."))
        #expect(text.contains("End on the point itself, with no request to the viewer."))
        #expect(!text.contains("on the takeaway") && !text.contains("do nothing"), "read out loud on an iPhone 18 Pro Max")
        #expect(text.contains(ScriptPromptBuilder.requestWinsRule), "B1: the request still wins")
    }

    @Test func aUsualActionIsTheOnlyOneAsked() {
        let text = whole(request(voice: voice(endings: ["Follow for more"])))
        #expect(!text.contains("comment, follow or save"))
        #expect(text.contains("CTA: the creator's own ending: inviting them to follow for more. Ask for nothing else."))
        #expect(text.contains("End by inviting them to follow for more."))
    }

    @Test func withoutAnEndingOfTheirsThePlatformStillEnds() {
        let text = whole(request(voice: voice(avoid: ["Hype words"])))
        #expect(text.contains("end with one easy action (comment, follow or save)"))
        #expect(text.contains("CTA: one clear action."))
    }

    // MARK: - "Calls to action" as the rule

    @Test func theRuleBeatsTheHabit() {
        let both = voice(endings: ["Follow for more", "See you Sunday"], avoid: ["Calls to action"])
        #expect(both.forbidsCallsToAction && both.endsWithoutAsking)
        #expect(both.endingActions == ["saying “See you Sunday”"], "Cue's endings that ask go; the sign-off they typed stays")
        let text = whole(request(voice: both))
        #expect(!text.contains("follow for more"), "\(text)")
        #expect(text.contains("no calls to action: never ask viewers to follow"))
        #expect(text.contains("Close: finish on the point itself, saying “See you Sunday”, with no request to the viewer."))
    }

    @Test func theRuleIsCheckedInTheScriptsOwnLanguage() {
        let never = voice(avoid: ["Calls to action"])
        let english = VoiceConstraintChecker.violations(in: "Lists hide the real work.\n\nFollow for more tips like this.", voice: never, language: .english)
        #expect(english.map(\.kind) == [.avoided])
        let portuguese = VoiceConstraintChecker.violations(
            in: "A lista esconde o trabalho de verdade.\n\nSalva esse vídeo e me segue para mais.", voice: never, language: .portugueseBrazil
        )
        #expect(portuguese.map(\.kind) == [.avoided])
        let calm = VoiceConstraintChecker.violations(in: "Lists hide the real work. Pick one task and start.", voice: never, language: .english)
        #expect(calm.isEmpty)
    }

    @Test func theHabitIsNeverCheckedAsARule() {
        let habit = voice(endings: ["No call to action"])
        #expect(VoiceConstraintChecker.violations(in: "One task at a time.\n\nFollow for more.", voice: habit, language: .english).isEmpty)
    }

    // MARK: - The request beats the "never" (B1)

    @Test func anIdeaThatAsksForItInSoManyWordsLiftsTheRuleAndSaysSo() {
        let never = voice(avoid: ["Calls to action"])
        let asking = request("Neste vídeo, peça para me seguirem: três hábitos de manhã", voice: never)
        #expect(VoiceConstraintChecker.lifted(by: asking) == ["Calls to action"])
        let script = "Três hábitos mudaram minhas manhãs.\n\nMe segue para mais."
        #expect(VoiceConstraintChecker.violations(in: script, voice: never, language: .portugueseBrazil, request: asking.creatorText).isEmpty)
        #expect(ScriptStarter.followedIdea(over: ["Calls to action"]).contains("Calls to action"))
    }

    @Test func anAccidentalContradictionLiftsNothing() {
        let never = voice(avoid: ["Exaggerated promises", "Calls to action"])
        #expect(VoiceConstraintChecker.lifted(by: request("Make a convincing ad for my course: which one is better?", voice: never)).isEmpty)
        #expect(VoiceConstraintChecker.lifted(by: request("Why to-do lists fail", voice: nil)).isEmpty, "no voice, nothing to lift")
    }

    // MARK: - Private Cloud Compute

    @Test func privateCloudComputeNoLongerForbidsTheFollowTheCreatorChose() {
        let text = whole(request(voice: voice(endings: ["Follow for more"]), on: .privateCloud))
        #expect(text.contains("ask for nothing beyond it; without an ending preference, avoid a generic follow"))
        #expect(text.contains("inviting them to follow for more"))
    }
}
