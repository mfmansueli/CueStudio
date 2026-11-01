//
//  ScriptToolsQualityDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// "Improve script" measured on the scripts creators really have: Ultra AI's (long, in short paragraphs, no cues), Apple Intelligence's (short,
/// full of cues) and their own (one block, typos, a cue or two), in English, Brazilian Portuguese and Spanish (and a Japanese and a German one), on
/// the device's model and on Private Cloud Compute. Each case is one tool on one script on one model; what came back is printed as a `TOOLRUN`
/// line for `tools/script_tools/collect.py` (and `report.py`, which holds each result to the tool's promise). Opt-in on a device with Apple
/// Intelligence, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device ScriptToolsQualityDeviceTests`, narrowed with
/// `TEST_RUNNER_CUE_TOOLS_QUALITY_TOOLS=fitToTime,newHooks`, `…_ROUTES=device|cloud`, `…_SCRIPTS=ultra-en-US-0,hand-pt-BR` (ids or origins) and
/// `…_RUN=<name>`.
@MainActor
@Suite("Script tools on real scripts", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_TOOLS_QUALITY"] != nil))
struct ScriptToolsQualityDeviceTests {
    nonisolated struct Script: Decodable, Sendable {
        let id: String
        let origin: String
        let language: String
        let title: String
        let text: String
    }

    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let script: String
        let tool: ScriptTool
        let route: AIModelRoute
        var testDescription: String { "\(script) · \(tool) · \(route == .privateCloud ? "cloud" : "device")" }
    }

    /// The scripts every tool runs on; "Fit to time" runs on all of them.
    nonisolated static let core: Set<String> = [
        "ultra-en-US-0", "ultra-es-ES-1", "ultra-pt-BR-0", "apple-en-US-full", "apple-es-ES-full", "apple-pt-BR-full", "apple-ja-JP", "hand-pt-BR",
        "hand-en-US", "hand-es-ES",
    ]

    nonisolated static let tools: [ScriptTool] = [
        .fitToTime, .shorterAndDirect, .fixGrammar, .moreEnergy, .moreHuman, .lessDefensive, .strongerCTA, .inMyVoice, .translate, .newHooks,
    ]

    nonisolated static let scripts: [Script] = {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "script-tools-corpus", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Script].self, from: data)) ?? []
    }()

    nonisolated static let cases: [Case] = {
        let environment = ProcessInfo.processInfo.environment
        func list(_ key: String) -> Set<String>? {
            environment["CUE_TOOLS_QUALITY_\(key)"].map { Set($0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }) }
        }
        let wantedTools = list("TOOLS")
        let wantedScripts = list("SCRIPTS")
        let routes: [AIModelRoute] = switch environment["CUE_TOOLS_QUALITY_ROUTES"] {
        case "device": [.onDevice]
        case "cloud": [.privateCloud]
        default: [.onDevice, .privateCloud]
        }
        return scripts.flatMap { script in
            tools.flatMap { tool in
                routes.map { Case(script: script.id, tool: tool, route: $0) }
            }
        }
        .filter { item in
            let script = scripts.first { $0.id == item.script }
            if let wantedScripts {
                guard wantedScripts.contains(item.script) || wantedScripts.contains(script?.origin ?? "") else { return false }
            } else if item.tool != .fitToTime, !core.contains(item.script) {
                return false
            }
            return wantedTools?.contains("\(item.tool)") ?? true
        }
    }()

    nonisolated static let run = ProcessInfo.processInfo.environment["CUE_TOOLS_QUALITY_RUN"] ?? "baseline"

    private final class BundleToken {}

    @Test(.timeLimit(.minutes(5)), arguments: ScriptToolsQualityDeviceTests.cases)
    func runTheTool(_ item: Case) async throws {
        KeepScreenAwake.enable()
        #if canImport(UIKit)
        try #require(UIApplication.shared.applicationState == .active, "The iPhone must be unlocked with the screen on")
        #endif
        let script = try #require(Self.scripts.first { $0.id == item.script })
        let service = item.route == .privateCloud ? ScriptAIService(preferredModel: .privateCloud) : ScriptAIService()
        let available = item.route == .privateCloud ? service.availability.privateCloud : service.availability.onDevice
        guard available else { try Test.cancel("\(item.route) isn't available on this iPhone") }

        let language = Locale.Language(identifier: script.language)
        let cueLanguage = CueLanguage(rawValue: script.language)
        let profile = QualityProfiles.all.first { $0.language == cueLanguage }?.profile(.full)
        let range = TestData.rulesService().preset(for: .tiktok, monetizationGoals: false).idealRange
        let target: CueLanguage = script.language.hasPrefix("en") ? .portugueseBrazil : .english
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: range, language: item.tool == .translate ? target : nil,
            sourceLanguage: language, voice: profile?.voice(inLanguage: language.languageCode?.identifier, idea: script.text)
        )

        var record = Record(
            run: Self.run, id: script.id, origin: script.origin, language: script.language, tool: "\(item.tool)",
            route: item.route == .privateCloud ? "cloud" : "device", range: [range.lowerBound, range.upperBound],
            target: item.tool == .translate ? target.rawValue : nil, hasVoice: context.voice != nil, before: script.text
        )
        let started = ContinuousClock.now
        for attempt in 1...3 {
            do {
                if item.tool == .newHooks {
                    record.hooks = try await service.hooks(for: script.text, context: context)
                } else {
                    let result = try await service.rewriteReported(script.text, with: item.tool, context: context)
                    record.after = result.text
                    record.parts = [result.parts, result.leftAsWritten]
                }
                record.failure = nil
                break
            } catch ScriptAIError.rateLimited where attempt < 3 {
                record.failure = "rateLimited"
                try? await Task.sleep(for: .seconds(30))
            } catch {
                record.failure = "\(error)"
                break
            }
        }
        record.seconds = started.duration(to: .now).inSeconds
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let line = String(bytes: try encoder.encode(record), encoding: .utf8) ?? ""
        print("TOOLRUN \(line)")
        Attachment.record(line, named: "tool-\(Self.run)-\(script.id)-\(item.tool)-\(record.route).json")
        #expect(record.after != nil || record.hooks != nil || record.failure != nil)
    }

    private struct Record: Encodable {
        let run: String
        let id: String
        let origin: String
        let language: String
        let tool: String
        let route: String
        let range: [TimeInterval]
        let target: String?
        let hasVoice: Bool
        let before: String
        var after: String?
        var hooks: [String]?
        /// The parts the script was worked in, and how many were left as they were.
        var parts: [Int]?
        var seconds: TimeInterval = 0
        var failure: String?
    }
}
