//
//  ScriptQualityPromptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the model is sent for every case of the script-quality measurement (`QualityProfiles`), before anything is written: the voice of a creator
/// who answered My Cue Voice in full reaches the prompt with their catchphrase, opening, ending and examples; a half-answered one with what they said;
/// none with nothing of it. The prompts are left in `build/reports/quality-prompts.txt` to be read.
@MainActor
@Suite("Script quality prompts")
struct ScriptQualityPromptTests {
    @Test(arguments: QualityProfiles.all)
    func everyConditionSendsWhatTheCreatorAnswered(_ profile: QualityProfile) {
        var report: [String] = []
        for condition in QualityProfile.Condition.allCases {
            for entry in profile.cases {
                let request = ScriptQualityDeviceTests.request(for: entry.idea, brief: entry.brief, profile: profile, condition: condition)
                let instructions = ScriptPromptBuilder.instructions(for: request)
                let prompt = ScriptPromptBuilder.prompt(for: request)
                report.append("===== \(profile.language.rawValue) · \(condition.rawValue) · \(entry.idea.prefix(60))\n--- instructions\n\(instructions)\n--- prompt\n\(prompt)\n")
                #expect(request.language == profile.language, "the script is written in the creator's language")
                switch condition {
                case .none:
                    #expect(request.voice == nil)
                case .half, .full:
                    #expect(request.voice != nil, "\(condition): the voice is on")
                    #expect(instructions.contains(profile.full.phrases[0]), "\(condition): the catchphrase reaches the model")
                }
                if condition == .full {
                    #expect(instructions.contains("Here is how they write"), "the full voice sends examples of their writing")
                    #expect(instructions.contains("End by"), "the full voice says how they end")
                }
                if entry.brief != nil {
                    #expect(prompt.contains(profile.brief.openingLine), "the brief's opening line is asked for")
                    #expect(prompt.contains(profile.brief.angle), "the brief's angle is followed")
                }
            }
        }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/reports")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? report.joined(separator: "\n").write(
            to: folder.appendingPathComponent("quality-prompts-\(profile.language.rawValue).txt"), atomically: true, encoding: .utf8
        )
    }
}
