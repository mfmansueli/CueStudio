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
        var voice = CreatorVoice(sounds: [.casual, .confident], phrases: ["Bora lá"], vocabulary: nil, styles: [])
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
        var request = ScriptRequest(source: .prompt(idea), platform: .tiktok, voice: voice, targetRange: 60...90)
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
        #expect(prompt.contains("Subject: Why saving feels harder than spending\n\(UltraPayload.keptTitleLine)"))
        #expect(!UltraPayload(request("Why saving feels harder than spending")).draft.prompt.contains(UltraPayload.keptTitleLine))
    }

    /// The editor keeps the idea's title when there is one, and writes a short one only for a request the creator typed.
    @Test func theEditorKeepsTheIdeasTitleAndTitlesATypedRequestShortly() {
        let editor = UltraPayload(request("A night routine")).review(of: "Draft.").instructions
        #expect(editor.contains("\"title\", the idea's title exactly as given after “Subject:” in the context when there is one"))
        #expect(editor.contains("otherwise a short title for the script in its language (at most eight words"))
    }

    /// A chosen format goes with what it needs, not only its name (the study of 04/11/2026); every format has its own definition.
    @Test func aChosenFormatGoesWithItsDefinition() {
        var story = request("The day I lost my first client")
        story.format = .story
        let line = UltraFormatGuide.line(for: story)
        #expect(line.hasPrefix("Format chosen by the creator: storytime, a story told from their own experience."))
        #expect(line.contains("each beat follows from the one before (but, so)"))
        for stage in [UltraPayload(story).draft, UltraPayload(story).review(of: "Draft.")] { #expect(stage.prompt.contains(line)) }
        var talking = request("Why I film in one take")
        talking.formatChoice = .talkingHead
        #expect(UltraFormatGuide.line(for: talking).hasPrefix("Format chosen by the creator: talking head (one person speaking to camera). It needs"))
        var lines = Set<String>()
        for type in ScriptType.allCases {
            var asked = request("An idea")
            asked.format = type
            let line = UltraFormatGuide.line(for: asked)
            #expect(line.hasPrefix("Format chosen by the creator: ") && line.count > 120, "\(type)")
            lines.insert(line)
        }
        #expect(lines.count == ScriptType.allCases.count)
    }

    /// On Auto an idea from the cards is written as its kind's genre, defined (the study of 04/11/2026); a typed idea reads its genre from the
    /// request, as before.
    @Test func onAutoACardsIdeaGetsItsGenreAndATypedOneReadsIt() {
        var card = request("The day I lost my first client")
        card.brief = IdeaBrief(subject: "The day I lost my first client", angle: "", openingLine: "", angleKind: IdeaAngle.story.rawValue)
        let line = UltraFormatGuide.line(for: card)
        #expect(line.hasPrefix("Format: not chosen by the creator. This idea is a short story from experience, so write it as a story told"))
        #expect(UltraPayload(card).draft.prompt.contains(line) && UltraPayload(card).review(of: "Draft.").prompt.contains(line))
        for kind in IdeaAngle.allCases {
            card.brief?.angleKind = kind.rawValue
            #expect(UltraFormatGuide.line(for: card).contains("This idea is \(kind.ask), so write it as "), "\(kind)")
        }
        let typed = UltraFormatGuide.line(for: request("The day I lost my first client"))
        #expect(typed.hasPrefix("Format: not chosen. Read the genre from the request"))
        card.brief?.angleKind = nil
        #expect(UltraFormatGuide.line(for: card) == typed, "a card without its kind reads the genre too")
    }

    /// On Auto every network is written to the request's range, YouTube's long form too (the owner's call, 04/11/2026: "o roteiro é sempre um
    /// rascunho inicial"); a length the creator chose is their intent.
    @Test func automaticLengthIsTheRequestsRangeOnEveryNetworkAndAChosenOneIsIntent() {
        var automatic = request("A night routine")
        automatic.durationPolicy = .informative
        let vertical = UltraPayload(automatic).draft.prompt
        #expect(vertical.contains("Length: 60 to 90 seconds of speech (about 150 to 225 words at a natural pace)"))
        #expect(vertical.contains("never go past 225 words"))
        automatic.platform = .youtube
        let long = UltraPayload(automatic).draft.prompt
        #expect(long.contains("Length: 60 to 90 seconds of speech") && !long.contains("Length: free."))
        #expect(UltraPayload(request("A night routine")).draft.prompt.contains("the creator chose 60 to 90 seconds"))
        #expect(UltraPayload(automatic, length: .reference(90)).draft.prompt.contains("about 90 seconds"))
    }

    /// A script comes back a little over a short range at most (15%), and never past the top of one that reaches the networks' 2:30 (375 words)
    /// ("sem ficar estourando limite de palavras", the owner, 04/11/2026); only Auto's range is fitted by itself.
    @Test func onlyTheNetworksRangeHasAnOverflowAndItNeverPassesTheTop() {
        #expect(UltraLength.ideal(60...90).overflowWords == 259)
        #expect(UltraLength.ideal(75...105).overflowWords == 302)
        #expect(UltraLength.ideal(15...30).overflowWords == 86)
        #expect(UltraLength.ideal(75...150).overflowWords == 375)
        #expect(UltraLength.ideal(120...150).overflowWords == 375)
        #expect(UltraLength.required(60...90).overflowWords == nil)
        #expect(UltraLength.free.overflowWords == nil)
    }

    @Test func theDraftKnowsWhoTheyAreAndOnlyThePolishHowTheySpeak() {
        let payload = UltraPayload(request("A night routine", voice: voice))
        #expect(payload.draft.prompt.contains("people starting their first budget"))
        #expect(!payload.draft.prompt.contains("How the creator speaks"))
        #expect(payload.review(of: "Draft.").prompt.contains("How the creator speaks"))
        #expect(payload.review(of: "Draft.").prompt.contains("Draft to polish:\n\"\"\"\nDraft.\n\"\"\""))
    }

    @Test func theCheckKnowsWhoTheyAreButNotHowTheySpeak() {
        let check = UltraPayload(request("A night routine", voice: voice)).check(of: "Draft.")
        #expect(check.stage == .check && check.instructions == UltraInstructions.checker)
        #expect(check.prompt.contains("people starting their first budget"))
        #expect(!check.prompt.contains("How the creator speaks"))
        #expect(check.prompt.hasSuffix("Draft to check:\n\"\"\"\nDraft.\n\"\"\""))
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
