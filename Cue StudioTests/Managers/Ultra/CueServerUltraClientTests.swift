//
//  CueServerUltraClientTests.swift
//  Cue StudioTests
//

import Foundation
import StoreKit
import Testing
@testable import Cue_Studio

/// Ultra AI through Cue's server: what the app sends (only the stage's words, its JSON shape and a lower effort when asked), how Claude's
/// streamed events become the reply (words, counts, the model, a refusal), and where a Release build offers Ultra (TestFlight, never the App
/// Store yet). The server's own side is tested in `server/functions` (`npm test`).
@Suite("Ultra AI · Cue's server")
struct CueServerUltraClientTests {
    private func request(_ stage: UltraStageRequest.Stage, thinking: UltraThinking = .model) -> UltraStageRequest {
        var request = UltraStageRequest(stage: stage, instructions: "You write scripts.", prompt: "Morning habits")
        request.thinking = thinking
        return request
    }

    private func event(_ json: String) -> String { "data: \(json)" }

    // MARK: - What goes to the server

    @Test func theDraftSendsItsWordsAndNoShapeOrEffort() {
        let body = CueServerUltraClient.body(for: request(.draft))
        #expect(body["stage"] as? String == "draft")
        #expect(body["system"] as? String == "You write scripts.")
        #expect(body["prompt"] as? String == "Morning habits")
        #expect(body["schema"] == nil)
        // The server's effort (`ULTRA_EFFORT`) decides unless the flow asks for a lower one.
        #expect(body["effort"] == nil)
        #expect(Set(body.keys) == ["stage", "system", "prompt"])
    }

    @Test func whoTheCallIsForGoesWithItAsTheServerReadsIt() throws {
        let install = UUID(), run = UUID()
        var stage = request(.review)
        stage.caller = UltraCaller(installID: install, runID: run, proof: "signed-pro")
        let body = CueServerUltraClient.body(for: stage)
        #expect(body["installId"] as? String == install.uuidString)
        #expect(body["scriptId"] as? String == run.uuidString)
        #expect(body["proof"] as? String == "signed-pro")
        // A fit names the install but no run; off Pro, no proof.
        var fit = request(.fit)
        fit.caller = UltraCaller(installID: install)
        let fitBody = CueServerUltraClient.body(for: fit)
        #expect(fitBody["installId"] as? String == install.uuidString && fitBody["scriptId"] == nil && fitBody["proof"] == nil)
    }

    @Test func theServersRefusalsAreReadByTheirName() {
        #expect(ClaudeStreamReader.failure(status: 402, refusal: "noCredits") == .outOfScripts)
        #expect(ClaudeStreamReader.failure(status: 503, refusal: "paused") == .paused)
        #expect(ClaudeStreamReader.failure(status: 429, refusal: "limited") == .limited)
        // Without a name, the status alone, as before metering.
        #expect(ClaudeStreamReader.failure(status: 429) == .rejected)
        #expect(ClaudeStreamReader.failure(status: 504) == .timedOut)
        #expect(ClaudeStreamReader.failure(status: 409, refusal: "script") == .provider)
    }

    @Test func theServersCountBecomesTheAllowanceOnlyWhileItEnforces() throws {
        let json = #"{"metering":"enforce","paused":false,"membership":"pro","freeLeft":2,"monthLeft":28,"left":30,"freeTotal":8,"monthTotal":30}"#
        let answer = try JSONDecoder().decode(UltraServerAllowance.self, from: Data(json.utf8))
        let allowance = try #require(answer.allowance)
        #expect(allowance.membership == .paid)
        #expect(allowance.freeLeft == 2 && allowance.monthLeft == 28 && allowance.left == 30)
        #expect(allowance.bonus == 5 && allowance.freeTotal == 8)
        var observing = answer
        observing.metering = "observe"
        #expect(observing.allowance == nil)
        let off = try JSONDecoder().decode(UltraServerAllowance.self, from: Data(#"{"metering":"off"}"#.utf8))
        #expect(off.allowance == nil)
    }

    @Test func aJSONStageSendsItsShapeWithEveryKeyRequired() throws {
        let body = CueServerUltraClient.body(for: request(.review))
        let schema = try #require(body["schema"] as? [String: Any])
        #expect(schema["type"] as? String == "object")
        #expect(schema["required"] as? [String] == ["changes", "script", "title"])
        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(JSONSerialization.isValidJSONObject(body))
    }

    @Test func aLowerThinkingLevelIsSentAsTheEffort() {
        #expect(CueServerUltraClient.body(for: request(.draft, thinking: .low))["effort"] as? String == "low")
        #expect(CueServerUltraClient.body(for: request(.fit, thinking: .medium))["effort"] as? String == "medium")
        // Low except the claim check, which keeps the server's.
        #expect(CueServerUltraClient.body(for: request(.check, thinking: .lowExceptCheck))["effort"] == nil)
    }

    @MainActor
    @Test func theLibrarysIdeasNeverGoThroughTheCreatorsServer() async {
        var asked = false
        let client = CueServerUltraClient(appCheckToken: { asked = true; return "token" })
        await #expect(throws: UltraClientError(failure: .rejected)) {
            _ = try await client.generate(request(.ideas)) { _ in }
        }
        #expect(!asked)
    }

    @MainActor
    @Test func withoutAnAppCheckTokenNothingIsSent() async {
        let client = CueServerUltraClient(appCheckToken: { throw UltraAppCheck.Unavailable() })
        await #expect(throws: UltraClientError(failure: .rejected)) {
            _ = try await client.generate(request(.draft)) { _ in }
        }
    }

    // MARK: - Claude's events

    @Test func theWordsCountsAndModelComeFromTheStream() throws {
        var reader = ClaudeStreamReader()
        let lines = [
            "event: message_start",
            event(
                #"{"type":"message_start","message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":3000,"#
                    + #""cache_read_input_tokens":500,"cache_creation_input_tokens":100,"output_tokens":1}}}"#
            ),
            "",
            event(#"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#),
            event(#"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Plan the hook"}}"#),
            event(#"{"type":"ping"}"#),
            event(#"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Wake up "}}"#),
            event(#"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"early."}}"#),
            event(#"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":2400}}"#),
            event(#"{"type":"message_stop"}"#),
        ]
        let grew = try lines.map { try reader.consume($0) }
        #expect(grew.filter { $0 }.count == 2)
        let reply = try reader.finished()
        #expect(reply.text == "Wake up early.")
        #expect(reply.finishedNormally)
        #expect(reply.modelVersion == "claude-sonnet-5-5")
        #expect(reply.promptTokens == 3600)
        #expect(reply.cachedTokens == 500)
        #expect(reply.outputTokens == 2400)
    }

    @Test func anAnswerCutAtTheCeilingIsNotTakenForAScript() throws {
        var reader = ClaudeStreamReader(model: "claude-opus-5-5")
        _ = try reader.consume(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"Half a"}}"#))
        _ = try reader.consume(event(#"{"type":"message_delta","delta":{"stop_reason":"max_tokens"},"usage":{"output_tokens":32000}}"#))
        let reply = try reader.finished()
        #expect(!reply.finishedNormally)
        #expect(reply.modelVersion == "claude-opus-5-5")
    }

    @Test func aRefusalIsBlockedAndAnErrorEventIsTheProvidersKindOnly() throws {
        var refused = ClaudeStreamReader()
        _ = try refused.consume(event(#"{"type":"message_delta","delta":{"stop_reason":"refusal"},"usage":{"output_tokens":3}}"#))
        #expect(throws: UltraClientError(failure: .blocked)) { try refused.finished() }
        var failed = ClaudeStreamReader()
        #expect(throws: UltraClientError(failure: .provider)) {
            try failed.consume(event(#"{"type":"error","error":{"type":"overloaded"}}"#))
        }
    }

    @Test func theServersStatusesReadAsTheAppsFailures() {
        #expect(ClaudeStreamReader.failure(status: 401) == .rejected)
        #expect(ClaudeStreamReader.failure(status: 429) == .rejected)
        #expect(ClaudeStreamReader.failure(status: 504) == .timedOut)
        #expect(ClaudeStreamReader.failure(status: 503) == .provider)
        #expect(ClaudeStreamReader.mapped(URLError(.notConnectedToInternet)) as? UltraClientError == UltraClientError(failure: .unreachable))
    }

    // MARK: - Where a Release build offers it

    @Test func onlyTheAppStoreHidesUltraUntilTheServerKeepsCredits() {
        #expect(UltraDistribution.allows(.sandbox))
        #expect(UltraDistribution.allows(.xcode))
        #expect(!UltraDistribution.allows(.production))
    }
}
