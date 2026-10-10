//
//  InspirationDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// Find inspiration on a real iPhone, with the model of the device: what a batch of six whole briefs (a title, the angle, an opening line) costs next to
/// the six titles the card asked for before, whether the briefs keep to what they promise (inside the field, an angle that is an instruction, an opening
/// line that claims nothing about the creator), and whether a script asked with the brief follows its angle and opens with its line, next to the same
/// idea sent as plain text. What is printed is the table to read: seconds, and what came back. Opt-in, on a device with Apple Intelligence, unlocked
/// and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device InspirationDeviceTests`.
@MainActor
@Suite("Find inspiration on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct InspirationDeviceTests {
    private let topics = [
        IdeaTopic(name: Niche.finance.promptName, label: Niche.finance.label, niche: .finance),
        IdeaTopic(name: "Daily Routine", label: "Daily Routine", niche: nil, subtopics: ["Bureaucracy"]),
    ]

    private func writer() throws -> ScriptAIService {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        return service
    }

    /// Opening lines that put something in the creator's mouth they may not have lived: a result, a number, a credential (English only; a hint for
    /// the reader, not a verdict).
    private static let claim = try? NSRegularExpression(
        pattern: #"\b(I|we) (lost|made|earned|saved|gained|grew|paid off|have been|'ve been|spent|tested|tried)\b|\bmy (clients|students|followers|patients)\b|\d+ ?%|\$\d|\b(study|studies|research|statistics) (show|says|found)"#,
        options: [.caseInsensitive]
    )

    private static func claims(_ text: String) -> Bool {
        claim?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - Ideas

    @Test func aBatchOfBriefsAgainstABatchOfTitles() async throws {
        let service = try writer()
        defer { ScriptAIService.writesIdeaBriefs = true }
        let inspiration = ["Why filling Italian bureaucracy forms takes me three tries"]
        var titleSeconds: [Double] = []
        var briefSeconds: [Double] = []
        var briefs: [IdeaBrief] = []
        // Turn about, so that a model warming up or a hot iPhone weighs on both alike.
        for round in 0..<4 {
            let asBriefs = round % 2 == 1
            ScriptAIService.writesIdeaBriefs = asBriefs
            let slots = IdeaTaste().slots(round: round, among: topics)
            let started = ContinuousClock.now
            let ideas = try await service.suggestIdeas(slots: slots, language: .english, voice: nil, inspiration: inspiration, priority: .waiting)
            let seconds = started.duration(to: .now).inSeconds
            if asBriefs { briefSeconds.append(seconds) } else { titleSeconds.append(seconds) }
            print(String(format: "INSPIRATION %@ batch %d: %.1f s, %d ideas", asBriefs ? "briefs" : "titles", round, seconds, ideas.count))
            for idea in ideas {
                guard let brief = idea.brief else {
                    print("INSPIRATION   \(idea.kind) · \(idea.topic ?? idea.niche.label) · \(idea.title)")
                    continue
                }
                briefs.append(brief)
                print("INSPIRATION   \(idea.kind) · \(idea.topic ?? idea.niche.label) · \(brief.subject) | \(brief.angle) | “\(brief.openingLine)”")
            }
            #expect(ideas.count >= 3)
            #expect(seconds < 60, "A batch took \(Int(seconds)) s")
            try await Task.sleep(for: .seconds(2))
        }
        let average = { (values: [Double]) in values.reduce(0, +) / Double(max(1, values.count)) }
        let fieldTrimmed = briefs.filter { $0.composerText.contains("…") }.count
        let claims = briefs.filter { Self.claims($0.openingLine) }
        let longAngles = briefs.filter { $0.angle.split(separator: " ").count > 16 }.count
        print(String(
            format: "INSPIRATION titles %.1f s on average, briefs %.1f s (×%.2f); %d briefs, %d cut for the field, %d angles over 16 words, %d opening lines with a claim",
            average(titleSeconds), average(briefSeconds), average(briefSeconds) / max(0.1, average(titleSeconds)), briefs.count, fieldTrimmed, longAngles,
            claims.count
        ))
        for brief in claims { print("INSPIRATION   claim? “\(brief.openingLine)”") }
        #expect(briefs.allSatisfy { $0.composerText.count <= IdeaPromptDraft.maxCharacters })
        #expect(claims.count <= 1, "Opening lines claimed things about the creator: \(claims.map(\.openingLine))")
    }

    // MARK: - A script from a brief

    @Test func aScriptFromABriefFollowsItsAngleAndOpensWithItsLine() async throws {
        let service = try writer()
        // Written here, in English: the catalogue's starters come in the iPhone's own language, which the angle's words below can't be
        // measured against.
        let brief = IdeaBrief(
            subject: "Why saving feels harder than spending", angle: "Explain one small habit that makes saving easier.",
            openingLine: "Saving isn’t just about willpower. It’s about what you make automatic.", language: "en", angleKind: IdeaAngle.tutorial.rawValue
        )
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults), scriptLanguage: nil,
            interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        let angleWords = IdeaFocus.words(in: brief.angle, language: "en")
        for run in 0..<2 {
            for withBrief in [true, false] {
                let text = withBrief ? brief.composerText : brief.subject
                let request = factory.request(idea: text, platform: .tiktok, format: nil, brief: withBrief ? brief : nil)
                let started = ContinuousClock.now
                // The model sometimes answers with nothing: that run is told and counted, not the end of the measurement.
                let script: GeneratedScript
                do {
                    script = try await service.generate(request)
                } catch {
                    print("INSPIRATION script \(withBrief ? "with brief" : "plain idea") run \(run): failed after \(started.duration(to: .now).inSeconds) s · \(error)")
                    continue
                }
                let seconds = started.duration(to: .now).inSeconds
                let spoken = CueParser.stripCues(script.text)
                let firstSentence = spoken.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
                let opening = IdeaBrief.tokens(in: brief.fitted().openingLine)
                // The script's start as long as the line (and a little more), not its first sentence: a line of two sentences is cut in half there.
                let firstWords = spoken.split { !$0.isLetter && !$0.isNumber }.prefix(opening.count + 3).joined(separator: " ")
                let firstTokens = IdeaBrief.tokens(in: firstWords)
                let opensWithLine = !opening.isEmpty && Double(opening.filter(firstTokens.contains).count) / Double(opening.count) >= 0.6
                let lowered = spoken.lowercased()
                let angleShare = Double(angleWords.filter { lowered.contains($0.prefix(5)) }.count) / Double(max(1, angleWords.count))
                print(String(
                    format: "INSPIRATION script %@ run %d: %.1f s, %d words, opens with the line: %@, angle words %.0f%% · “%@”",
                    withBrief ? "with brief" : "plain idea", run, seconds, ReadTime.wordCount(in: spoken), opensWithLine ? "yes" : "no", angleShare * 100,
                    String(firstSentence.prefix(120))
                ))
                print("INSPIRATION   \(spoken.replacingOccurrences(of: "\n", with: " ⏎ "))")
                #expect(seconds < 60, "A script took \(Int(seconds)) s")
                if withBrief { #expect(opensWithLine, "The script didn't open with the line: \(firstSentence)") }
                try await Task.sleep(for: .seconds(2))
            }
        }
    }
}
