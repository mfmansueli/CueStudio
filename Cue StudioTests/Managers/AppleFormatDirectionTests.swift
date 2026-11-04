//
//  AppleFormatDirectionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Ultra study's improvements on Apple Intelligence's request (`ScriptPromptBuilder.definesFormats`, `followsIdeaKind`): each says what it
/// promises when on, and the request stays as it was when off. Measured on two iPhones (04/11/2026): a card's kind is on for the device only.
@MainActor
struct AppleFormatDirectionTests {
    private func chosen(_ type: ScriptType?, voice: CreatorVoice? = nil, on route: AIModelRoute = .onDevice) -> ScriptRequest {
        var request = ScriptRequest(source: .prompt("Morning habits"), platform: .tiktok, voice: voice, targetRange: 30...60, language: .english)
        request.format = type
        request.durationPolicy = .informative
        return AIRequestPolicy.prepare(request, on: route)
    }

    /// A Portuguese myth from the cards, for a creator who films lists: before, the device's guess (English words only) took their usual list.
    private func card(kind: String = "myth", on route: AIModelRoute = .onDevice) -> ScriptRequest {
        var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [])
        voice.formats = [.list]
        var request = ScriptRequest(
            source: .prompt("Pele oleosa não precisa de hidratante"), platform: .tiktok, voice: voice, targetRange: 30...60,
            language: .portugueseBrazil
        )
        request.durationPolicy = .informative
        request.brief = IdeaBrief(
            subject: "Pele oleosa não precisa de hidratante", angle: "Desmonte o mito.", openingLine: "Esse é o maior mito da pele oleosa.",
            language: "pt", angleKind: kind
        )
        return AIRequestPolicy.prepare(request, on: route)
    }

    private func whole(_ request: ScriptRequest) -> String {
        ScriptPromptBuilder.instructions(for: request) + "\n" + ScriptPromptBuilder.prompt(for: request)
    }

    // MARK: - A chosen format's definition

    @Test func offAChosenFormatKeepsWhatEachBlockDoes() {
        let prompt = ScriptPromptBuilder.prompt(for: chosen(.story))
        #expect(prompt.contains("What each block does: Hook:"))
        #expect(!prompt.contains(ScriptFormatDefinitions.chosenLine(for: .story)))
    }

    @Test func onAChosenFormatSaysWhatItNeedsInPlaceOfItsBlocksPurposes() {
        ScriptPromptBuilder.$definesFormats.withValue(true) {
            for route in [AIModelRoute.onDevice, .privateCloud] {
                for type in ScriptType.allCases {
                    let prompt = ScriptPromptBuilder.prompt(for: chosen(type, on: route))
                    #expect(prompt.contains(ScriptFormatDefinitions.chosenLine(for: type)), "\(type) on \(route)")
                    #expect(prompt.contains("Blocks, in this order:"), "\(type) on \(route)")
                    #expect(!prompt.contains("What each block does"), "\(type) on \(route)")
                }
            }
            var talking = chosen(nil)
            talking.formatChoice = .talkingHead
            #expect(ScriptPromptBuilder.prompt(for: talking).contains(ScriptFormatDefinitions.talkingHeadLine))
        }
    }

    /// The definition says nothing of how this creator ends: their own ending stays (the owner's B1 and B11).
    @Test func theCreatorsOwnEndingStaysBesideTheDefinition() {
        var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [])
        voice.endings = ["No call to action"]
        ScriptPromptBuilder.$definesFormats.withValue(true) {
            let prompt = ScriptPromptBuilder.prompt(for: chosen(.tutorial, voice: voice))
            #expect(prompt.contains("\(FormatGuide.closeBlock): finish on the point itself"))
        }
    }

    // MARK: - An idea's kind on Auto

    @Test func offACardsMythFollowsTheCreatorsUsualListOnTheDevice() {
        ScriptPromptBuilder.$followsIdeaKind.withValue(false) {
            let prompt = ScriptPromptBuilder.prompt(for: card())
            #expect(prompt.contains("Write a list of tips script"))
            #expect(!prompt.contains("This idea is a myth to bust"))
        }
    }

    /// The default: the device writes a card's myth as a myth, and an idea of a kind with no format of its own in the generic blocks, with its genre.
    @Test func aCardsMythIsWrittenAsAMythOnTheDevice() throws {
        let mythLine = try #require(ScriptFormatDefinitions.ideaLine(for: .myth))
        let factLine = try #require(ScriptFormatDefinitions.ideaLine(for: .fact))
        let prompt = ScriptPromptBuilder.prompt(for: card())
        #expect(prompt.contains("Write a myth vs fact script"))
        #expect(prompt.contains(mythLine))
        #expect(!prompt.contains("What each block does"))
        let fact = ScriptPromptBuilder.prompt(for: card(kind: "fact"))
        #expect(fact.contains("Write a talking video script"))
        #expect(fact.contains(factLine))
    }

    /// Off by default on Private Cloud Compute (measured no better there); a measurement that turns it on sends the genre in place of the menu.
    @Test func onPrivateCloudComputeTheIdeasGenreReplacesTheMenuOfGenres() throws {
        let menu = "Choose a tutorial for teaching a process"
        let mythLine = try #require(ScriptFormatDefinitions.ideaLine(for: .myth))
        #expect(whole(card(on: .privateCloud)).contains(menu))
        ScriptPromptBuilder.$followsIdeaKind.withValue(true) {
            let text = whole(card(on: .privateCloud))
            #expect(!text.contains(menu))
            #expect(text.contains(mythLine))
            // A typed idea has no kind: it keeps reading its genre from the request.
            var typed = card(on: .privateCloud)
            typed.brief = nil
            #expect(whole(typed).contains(menu))
        }
    }

    @Test func aLivedKindGetsTheStorysHonestyRule() {
        #expect(ScriptPromptBuilder.isFirstPersonStory(card(kind: "beforeAfter")))
        #expect(ScriptPromptBuilder.isFirstPersonStory(card(kind: "lesson")))
        #expect(!ScriptPromptBuilder.isFirstPersonStory(card(kind: "myth")))
    }
}
