//
//  VoiceAgreementTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Gender agreement and the form of address (the owner's B8, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11.7, A10).
/// Measured before (iPhone 15 Pro, 01/11/2026): women writing in Portuguese, Spanish, Italian and French got masculine forms, with nothing in the
/// profile that could say otherwise.
@MainActor
struct VoiceAgreementTests {
    private func voice(_ agreement: VoiceAgreement, speaksAs: SpeaksAs = .i) -> CreatorVoice {
        var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [])
        voice.agreement = agreement
        voice.speaksAs = speaksAs
        return voice
    }

    private func request(_ idea: String, language: CueLanguage, voice: CreatorVoice?) -> ScriptRequest {
        ScriptRequest(source: .prompt(idea), platform: .tiktok, voice: voice, targetRange: 30...60, language: language)
    }

    // MARK: - What the AI is told

    @Test func aChosenFeminineIsSaidInTheScriptsLanguage() {
        let lines = AgreementGuide.lines(for: VoiceAgreement(speaker: .feminine), speaksAs: .i, language: "pt-BR")
        #expect(lines.contains { $0.hasPrefix("In Portuguese, every word about the creator agrees in the feminine (cansada") })
        let instructions = ScriptPromptBuilder.instructions(for: request("Meu primeiro mês treinando", language: .portugueseBrazil,
                                                                         voice: voice(VoiceAgreement(speaker: .feminine))))
        #expect(instructions.contains("agrees in the feminine"))
    }

    @Test func notChosenIsNeverTheMasculine() {
        let lines = AgreementGuide.lines(for: nil, speaksAs: .i, language: "es-ES")
        #expect(lines.contains("In Spanish, the creator's gender isn't known: prefer wording about them that marks none, and never assume the masculine."))
        #expect(!lines.contains { $0.contains("agrees in the masculine") })
    }

    @Test func noGenderIsRephrasedNeverInvented() {
        let line = AgreementGuide.lines(for: VoiceAgreement(speaker: .neutral), speaksAs: .i, language: "fr-FR").first
        #expect(line?.contains("rephrase so no word about them marks one") == true && line?.contains("never with invented forms") == true)
    }

    @Test func aTeamAgreesAsTheGroupNotAsThePerson() {
        let agreement = VoiceAgreement(speaker: .masculine, group: .feminine)
        let lines = AgreementGuide.lines(for: agreement, speaksAs: .we, language: "es-ES")
        #expect(lines.contains("In Spanish, “we” is a group written in the feminine (nosotras, cansadas)."))
        #expect(!lines.contains { $0.contains("every word about the creator") })
        #expect(AgreementGuide.lines(for: VoiceAgreement(speaker: .feminine), speaksAs: .we, language: "it-IT")
            .allSatisfy { !$0.contains("feminine") }, "a group nobody described isn't given the speaker's gender")
    }

    @Test func englishGetsNoLineAtAll() {
        #expect(AgreementGuide.lines(for: VoiceAgreement(speaker: .feminine, address: .formal), speaksAs: .i, language: "en-US").isEmpty)
    }

    @Test func theFormOfAddressIsInformalUnlessFormalIsPicked() {
        #expect(AgreementGuide.lines(for: nil, speaksAs: .i, language: "de-DE") == ["Address the viewer informally (du), as a friend."])
        #expect(AgreementGuide.lines(for: VoiceAgreement(address: .formal), speaksAs: .i, language: "de-DE")
            == ["Address the viewer formally (Sie) throughout."])
        #expect(AgreementGuide.lines(for: nil, speaksAs: .i, language: "pt-PT").contains("Address the viewer informally (tu), as a friend."))
        #expect(AgreementGuide.lines(for: nil, speaksAs: .i, language: "pt-BR").contains("Address the viewer informally (você), as a friend."))
        #expect(AgreementGuide.lines(for: nil, speaksAs: .i, language: "ko-KR").isEmpty, "Korean's polite form stays the model's own")
        let korean = AgreementGuide.lines(for: VoiceAgreement(address: .formal), speaksAs: .i, language: "ko-KR")
        #expect(korean == ["Address the viewer formally (존댓말) throughout."])
    }

    @Test func aToolSaysOnlyWhatWasChosen() {
        #expect(AgreementGuide.lines(for: VoiceAgreement(), speaksAs: .i, language: "es-ES", chosenOnly: true).isEmpty)
        let rules = voice(VoiceAgreement(speaker: .feminine)).restrictionsOnly
        let lines = ScriptPromptBuilder.rewriteInstructions(rules: rules, language: Locale.Language(identifier: "it-IT"))
        #expect(lines.contains("In Italian, every word about the creator agrees in the feminine"))
        #expect(!lines.contains("Address the viewer"), "an edit doesn't change the address nobody chose")
    }

    @Test func ultraAndPrivateCloudComputeGetTheSameLines() {
        var asked = request("Il mio primo mese in palestra", language: .italian, voice: voice(VoiceAgreement(speaker: .feminine)))
        #expect(UltraPayload(asked).draft.prompt.contains("In Italian, every word about the creator agrees in the feminine"))
        asked = AIRequestPolicy.prepare(asked, on: .privateCloud)
        #expect(ScriptPromptBuilder.instructions(for: asked).contains("In Italian, every word about the creator agrees in the feminine"))
    }

    // MARK: - The check after writing

    @Test func theWrongGenderIsCaughtAfterTheVerbThatCarriesIt() {
        let feminine = VoiceAgreement(speaker: .feminine)
        #expect(GenderAgreementChecker.findings(in: "Eu estou muito cansado hoje.", agreement: feminine, speaksAs: .i, language: "pt-BR") == ["cansado"])
        #expect(GenderAgreementChecker.findings(in: "Ayer me quedé solo en casa.", agreement: feminine, speaksAs: .i, language: "es-ES") == ["solo"])
        #expect(GenderAgreementChecker.findings(in: "Je suis allé au marché.", agreement: feminine, speaksAs: .i, language: "fr-FR") == ["allé"])
        #expect(GenderAgreementChecker.findings(in: "Sono arrivato tardi.", agreement: feminine, speaksAs: .i, language: "it-IT") == ["arrivato"])
    }

    @Test func theRightGenderAndOtherPeoplesWordsAreLeftAlone() {
        let feminine = VoiceAgreement(speaker: .feminine)
        #expect(GenderAgreementChecker.findings(in: "Eu estou cansada. Meu marido ficou cansado.", agreement: feminine, speaksAs: .i,
                                                language: "pt-BR").isEmpty, "his tiredness is his")
        #expect(GenderAgreementChecker.findings(in: "Il treno era pronto.", agreement: feminine, speaksAs: .i, language: "it-IT") == [],
                "“era” is the train’s, not the creator’s")
        #expect(GenderAgreementChecker.findings(in: "Estou cansado.", agreement: VoiceAgreement(), speaksAs: .i, language: "pt-BR").isEmpty,
                "not chosen: counted by the battery, never a rule")
        #expect(GenderAgreementChecker.findings(in: "I am tired.", agreement: feminine, speaksAs: .i, language: "en-US").isEmpty)
    }

    @Test func noGenderCatchesBoth() {
        let neutral = VoiceAgreement(speaker: .neutral)
        #expect(GenderAgreementChecker.findings(in: "Fiquei cansada e depois animado.", agreement: neutral, speaksAs: .i, language: "pt-BR")
            .count == 1, "“animado” follows “e depois”, not a lead: only “cansada”")
        #expect(GenderAgreementChecker.findings(in: "Je suis prête.", agreement: neutral, speaksAs: .i, language: "fr-FR") == ["prête"])
    }

    @Test func aGroupIsCheckedInThePlural() {
        let group = VoiceAgreement(group: .feminine)
        #expect(GenderAgreementChecker.findings(in: "Llegamos cansados al final.", agreement: group, speaksAs: .we, language: "es-ES") == ["cansados"])
        #expect(GenderAgreementChecker.findings(in: "Siamo arrivati presto.", agreement: group, speaksAs: .we, language: "it-IT") == ["arrivati"])
        #expect(GenderAgreementChecker.findings(in: "Siamo arrivate presto.", agreement: group, speaksAs: .we, language: "it-IT").isEmpty)
    }

    @Test func aScriptInTheWrongGenderIsWrittenOnceMore() async throws {
        var calls = 0
        let writing = VoiceCheckedWriting(draft: { _, violations in
            calls += 1
            if calls == 2 { #expect(violations.contains { $0.kind == .agreement && $0.detail.contains("use the feminine") }) }
            return GeneratedScript(title: "Treino", text: calls == 1 ? "Eu estou cansado, mas fui." : "Eu estou cansada, mas fui.", usedLanguageModel: true)
        }, isGuardrailRefusal: { _ in false }, report: { _, _ in })
        let script = try await writing.write(request("Meu treino de hoje", language: .portugueseBrazil, voice: voice(VoiceAgreement(speaker: .feminine))))
        #expect(calls == 2 && script.text.contains("cansada") && !script.voiceViolations.contains(.agreement))
    }

    // MARK: - Kept, and cleared

    @Test func itIsKeptWithTheProfileAndAsARule() throws {
        var profile = CreatorProfile()
        profile.agreement = VoiceAgreement(speaker: .feminine, group: .neutral, address: .formal)
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.agreement == profile.agreement)
        #expect(try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(CreatorProfile())).agreement.isEmpty)
        #expect(profile.voice.agreement == profile.agreement && profile.voice.restrictionsOnly.agreement == profile.agreement)
    }

    @Test func theEditorsChoicesLandWhereTheyShould() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.setSpeakerGender(.feminine)
        service.setGroupGender(.masculine)
        service.setAddressForm(.formal)
        #expect(service.profile.agreement == VoiceAgreement(speaker: .feminine, group: .masculine, address: .formal))
        service.setAddressForm(.informal)
        #expect(service.profile.agreement.address == nil, "informal is the default, kept as nothing")
        service.setSpeakerGender(nil)
        #expect(service.profile.agreement.speaker == nil)
    }
}
