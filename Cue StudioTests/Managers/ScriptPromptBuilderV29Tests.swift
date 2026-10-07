//
//  ScriptPromptBuilderV29Tests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptPromptBuilder · v29")
struct ScriptPromptBuilderV29Tests {
    private let brand = BrandBrief(
        name: "Oat & Co.", product: "Barista oat milk", mustSay: "Froths like dairy", neverSay: "Health claims",
        link: "oatandco.com/maya", code: "MAYA10"
    )

    private func adRequest(brand: BrandBrief?) -> ScriptRequest {
        ScriptRequest(
            source: .prompt("A morning coffee routine"), platform: .tiktok, tone: nil, voice: nil, targetRange: 30...45,
            language: nil, format: .ad, brand: brand
        )
    }

    @Test func theBrandBriefIsPartOfThePromptAndNothingIsInvented() {
        let prompt = ScriptPromptBuilder.prompt(for: adRequest(brand: brand))
        #expect(prompt.contains("Brand: Oat & Co."))
        #expect(prompt.contains("Product or offer: Barista oat milk"))
        #expect(prompt.contains("Must say: Froths like dairy"))
        #expect(prompt.contains("Never say or mention: Health claims"))
        #expect(prompt.contains("Code: MAYA10"))
        #expect(prompt.contains("Never invent claims"))
        #expect(prompt.contains("#ad"))
    }

    @Test func emptyOptionalFieldsAreLeftOut() {
        let prompt = ScriptPromptBuilder.prompt(for: adRequest(brand: BrandBrief(name: "Lumen", product: "Desk lamp")))
        #expect(!prompt.contains("Must say"))
        #expect(!prompt.contains("Link:"))
    }

    @Test func noBrandNoBrief() {
        #expect(!ScriptPromptBuilder.prompt(for: adRequest(brand: nil)).contains("Use only the facts below"))
    }

    @Test func aFormatBriefIsReplacedByTheBrandBriefForAnAd() {
        let request = ScriptRequest(
            source: .format(.ad, brief: ["brand": "Old brand"]), platform: .tiktok, tone: nil, voice: nil, targetRange: 30...45,
            brand: brand
        )
        let prompt = ScriptPromptBuilder.prompt(for: request)
        #expect(prompt.contains("Oat & Co."))
        #expect(!prompt.contains("Old brand"))
    }

    @Test func thePersonalityAndProofLayersReachTheInstructions() {
        var profile = CreatorProfile(niches: [.tech], role: .personal)
        profile.confirm(.audience)
        profile.confirm(.tone)
        profile.openings = ["Okay, real talk."]
        profile.endings = ["Save this."]
        profile.formats = [.tutorial]
        profile.swearing = .never
        profile.customTags = ["Slow living"]
        profile.examples = [VoiceExample(text: "Here is how I really write.")]
        let brief = ScriptPromptBuilder.voiceBrief(profile)
        #expect(brief.contains("“Okay, real talk.”"), "an opening the creator typed is told as typed")
        #expect(brief.contains("“Save this.”"), "so is an ending that is none of Cue's (this one has a full stop)")
        #expect(brief.contains("tutorials"))
        #expect(brief.contains("Never swear."))
        #expect(brief.contains("Slow living"))
        #expect(brief.contains("Here is how I really write."))
    }

    @Test func mildSwearingNeverMeansStrongSwearing() {
        var profile = CreatorProfile(niches: [.tech])
        profile.confirm(.audience)
        profile.confirm(.tone)
        profile.swearing = .mild
        #expect(ScriptPromptBuilder.voiceBrief(profile).contains("Never write strong swearing or slurs."))
    }

    @Test func theVoiceBriefIsEmptyUntilThereIsEnoughToSend() {
        #expect(ScriptPromptBuilder.voiceBrief(CreatorProfile()).isEmpty)
    }
}
