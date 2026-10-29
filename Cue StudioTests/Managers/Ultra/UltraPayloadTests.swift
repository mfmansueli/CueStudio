//
//  UltraPayloadTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Ultra AI sends, read as text: the creator's exact words, the language, the words to say literally, Find inspiration's angle and opening,
/// the length policy, the voice split between the draft (who they are) and the polish (how they speak), and never their writing samples.
@MainActor
@Suite("Ultra AI payload")
struct UltraPayloadTests {
    private static let sampleMarker = "PRIVATE-SAMPLE-SENTENCE"
    private static let excerptMarker = "PRIVATE-EXCERPT-SENTENCE"
    private static let approvedMarker = "PRIVATE-APPROVED-SCRIPT"

    private var voice: CreatorVoice {
        var voice = CreatorVoice(sounds: [.casual, .confident], phrases: ["Bora lá"], vocabulary: nil, styles: [], niches: [.finance])
        voice.audienceNote = "people starting their first budget"
        voice.style.sentences = .short
        voice.reach.length = .under30
        voice.endings = ["Ask a question to the audience"]
        voice.examples = [VoiceExample(text: "\(Self.sampleMarker) is a whole sentence the creator once wrote in a caption.")]
        voice.excerpts = [VoiceExcerpt(text: "\(Self.excerptMarker) comes from a post the creator imported, long enough to count as one.")]
        voice.approvedSamples = [VoiceExample(text: "\(Self.approvedMarker) was a script the creator approved earlier.")]
        return voice
    }

    private func request(_ idea: String, voice: CreatorVoice? = nil) -> ScriptRequest {
        var request = ScriptRequest(source: .prompt(idea), platform: .tiktok, tone: nil, voice: voice, targetRange: 60...90)
        request.engine = .ultra
        return request
    }

    @Test func writingSamplesExcerptsAndApprovedScriptsNeverGo() {
        let payload = UltraPayload(request("Why I stopped buying bottled water", voice: voice))
        for text in [payload.draft.prompt, payload.review(of: "Draft.").prompt, payload.draft.instructions, payload.review(of: "Draft.").instructions] {
            #expect(!text.contains(Self.sampleMarker))
            #expect(!text.contains(Self.excerptMarker))
            #expect(!text.contains(Self.approvedMarker))
        }
    }

    @Test func theCreatorsWordsGoExactlyAsTyped() {
        let idea = "Três hábitos que   mudaram minhas finanças — e um que eu odeio"
        let payload = UltraPayload(request(idea))
        #expect(payload.draft.prompt.contains("\"\"\"\n\(idea)\n\"\"\""))
        #expect(payload.review(of: "x").prompt.contains("\"\"\"\n\(idea)\n\"\"\""))
    }

    @Test func theLanguageIsNamedOrLeftToTheRequest() {
        var asked = request("Por que parei de comprar água")
        #expect(UltraPayload(asked).draft.prompt.contains("Write the script in the language of the creator's request."))
        asked.language = .portugueseBrazil
        #expect(UltraPayload(asked).draft.prompt.contains("Write the script in \(ScriptPromptBuilder.languageName(.portugueseBrazil))."))
    }

    @Test func wordsAskedLiterallyAreRepeated() {
        let asked = request("A video about budgeting apps. Say exactly: \"use o código CUE10\" at the end")
        #expect(!asked.requiredPhrases.isEmpty)
        let prompt = UltraPayload(asked).draft.prompt
        for phrase in asked.requiredPhrases { #expect(prompt.contains("“\(phrase)”")) }
    }

    @Test func findInspirationsAngleAndOpeningGo() {
        var asked = request("Why saving feels harder than spending")
        asked.brief = IdeaBrief(
            subject: "Why saving feels harder than spending", angle: "Explain one small habit that makes saving easier.",
            openingLine: "Saving isn’t just about willpower.", angleKind: "fact", topicKey: "finance"
        )
        let prompt = UltraPayload(asked).draft.prompt
        #expect(prompt.contains("Follow this angle all the way through: Explain one small habit that makes saving easier."))
        #expect(prompt.contains("Saving isn’t just about willpower."))
    }

    @Test func automaticLengthIsInformationAndAChosenOneIsIntent() {
        var automatic = request("A night routine")
        automatic.durationPolicy = .informative
        #expect(UltraPayload(automatic).draft.prompt.contains("Length: free."))
        #expect(UltraPayload(request("A night routine")).draft.prompt.contains("the creator chose 60 to 90 seconds"))
        #expect(UltraPayload(automatic, length: .reference(90)).draft.prompt.contains("about 90 seconds"))
    }

    @Test func theDraftKnowsWhoTheyAreAndOnlyThePolishHowTheySpeak() {
        let payload = UltraPayload(request("A night routine", voice: voice))
        #expect(payload.draft.prompt.contains("people starting their first budget"))
        #expect(!payload.draft.prompt.contains("How the creator speaks"))
        #expect(payload.review(of: "Draft.").prompt.contains("How the creator speaks"))
        #expect(payload.review(of: "Draft.").prompt.contains("Draft to polish:\n\"\"\"\nDraft.\n\"\"\""))
    }

    @Test func preferencesNeverMakeTheScriptShort() {
        let review = UltraPayload(request("A night routine", voice: voice)).review(of: "Draft.").prompt
        // Their usual video length isn't sent, and short sentences are a rhythm, never a limit.
        #expect(!review.contains(VideoLength.under30.promptName))
        #expect(review.contains("never a limit on how much the script develops"))
        #expect(review.contains("preferences, not a new request"))
    }

    @Test func noHabitualCallToActionIsAsked() {
        #expect(UltraInstructions.writer.contains("comment, like or follow out of habit"))
        #expect(UltraInstructions.editor.contains("add a call to action only when the request asks for one"))
    }
}
