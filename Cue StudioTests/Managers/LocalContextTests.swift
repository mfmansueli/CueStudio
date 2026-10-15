//
//  LocalContextTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What of the creator's own material reaches the model for one idea: an example on the video's own subject goes after the others (the baseline run
/// copied one), the newest approved script leads, and the catchphrase in front of an idea's opening line is the script's to place.
@Suite("Local context")
struct LocalContextTests {
    @Test func anExampleAboutTheIdeaGoesAfterTheOthers() {
        var profile = CreatorProfile(niches: [.beauty], phrases: ["Fala, galera!"], confirmedVoiceSteps: [.audience, .tone])
        profile.examples = [
            VoiceExample(text: "Pare de passar o protetor solar só no rosto! O pescoço também precisa de protetor solar."),
            VoiceExample(text: "Minha rotina de noite é simples, só quatro passos: limpar, tonificar, hidratar e dormir."),
        ]
        let voice = profile.voice(inLanguage: "pt", idea: "Por que protetor solar barato também funciona")
        #expect(voice.examples.first?.text.hasPrefix("Minha rotina") == true)
        #expect(voice.examples.count == 2, "nothing is thrown away")
    }

    @Test func anExcerptAboutTheIdeaIsPickedLast() {
        let library = [
            VoiceExcerpt(text: "Pare de passar o protetor solar só no rosto. O pescoço também precisa.", language: "pt", role: .opening),
            VoiceExcerpt(text: "Fala, galera! Cinco produtos baratos que eu uso todo dia, nenhum passa de vinte reais.", language: "pt", role: .opening),
        ]
        let picked = ExcerptRetriever.pick(from: library, context: .init(language: "pt", idea: "Por que protetor solar barato funciona"), limit: 1)
        #expect(picked.first?.text.hasPrefix("Fala, galera! Cinco") == true)
    }

    @Test func theCatchphraseInFrontOfAnIdeasOpeningLineIsLeftToTheScript() {
        #expect(IdeaBriefReader.withoutCatchphrase("Fala, galera! Escolher bem os produtos é essencial.", phrases: ["Fala, galera!"])
            == "Escolher bem os produtos é essencial.")
        #expect(IdeaBriefReader.withoutCatchphrase("Hola, familia. Hoy probamos un esmalte nuevo.", phrases: ["Hola, familia."])
            == "Hoy probamos un esmalte nuevo.")
        #expect(IdeaBriefReader.withoutCatchphrase("Fala, galera! Bora?", phrases: ["Fala, galera!"]) == "Fala, galera! Bora?", "too little left")
        #expect(IdeaBriefReader.withoutCatchphrase("Your workout starts before the first squat.", phrases: ["Okay, real talk."])
            == "Your workout starts before the first squat.")
    }

    @Test func aBriefsAngleAndOpeningLineGoToTheModelOnceAsRules() {
        let brief = IdeaBrief(
            subject: "The warm-up most people skip", angle: "Show a five-minute warm-up anyone can do at home.",
            openingLine: "Your workout starts before the first squat."
        )
        let request = ScriptRequest(
            source: .prompt(brief.composerText + "\nKeep it light."), platform: .tiktok, tone: nil, voice: nil, targetRange: 30...45, language: .english,
            brief: brief
        )
        #expect(ScriptPromptBuilder.videoText(for: request) == "The warm-up most people skip\nKeep it light.", "what the creator added stays")
        let prompt = ScriptPromptBuilder.prompt(for: request)
        #expect(prompt.components(separatedBy: brief.openingLine).count == 2, "the opening line is asked for once")
        #expect(prompt.components(separatedBy: brief.angle).count == 2, "the angle is asked for once")
    }

    @Test func aShortGreetingSaidFirstIsCountedButNeverWrittenAgainFor() {
        var voice = CreatorProfile(niches: [.beauty], phrases: ["Fala, galera!"], confirmedVoiceSteps: [.audience, .tone], openings: ["Question"]).voice
        voice.speaksAs = .i
        let found = VoiceConstraintChecker.violations(in: "Fala, galera! Você erra isso toda manhã?", voice: voice)
        #expect(found.map(\.kind) == [.catchphraseFirst])
        let allSoft = found.allSatisfy(\.isSoft)
        #expect(allSoft)
        voice.phrases = ["This is how we do it every single day"]
        let long = VoiceConstraintChecker.violations(in: "This is how we do it every single day. Here's why.", voice: voice)
        #expect(long.contains { $0.kind == .catchphraseFirst && !$0.isSoft }, "a long catchphrase first is still written again for")
    }
}
