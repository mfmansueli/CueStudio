//
//  VoiceCheckedWriting.swift
//  Cue Studio
//

import Foundation

/// Writes a script and keeps it to what the creator asked (plan stage 3, item 7), whatever model does the writing: the one thing that decides
/// is passed in (`draft`), so it can be tested without one.
///
/// - The model refusing a request that carries the creator's own words (a guardrail) is answered once with a request that has only what Cue offers.
/// - A script that breaks their rules (`VoiceConstraintChecker`) is written once more, told which rule.
/// - It never blocks: if the new attempt fails or is no better, the first script stands.
@MainActor
struct VoiceCheckedWriting {
    /// Writes the script for a request; the violations are what the last draft got wrong, empty for the first attempt.
    let draft: (ScriptRequest, [VoiceViolation]) async throws -> GeneratedScript
    /// Whether an error is the framework refusing the request itself (its guardrails), not the answer.
    let isGuardrailRefusal: (any Error) -> Bool
    /// Written down: an attempt that failed and was answered another way (the error, the step).
    let report: (any Error, String) -> Void

    func write(_ request: ScriptRequest) async throws -> GeneratedScript {
        var request = request
        var use: VoiceUse = request.voice == nil ? .none : .full
        var script: GeneratedScript
        do {
            script = try await draft(request, [])
        } catch where request.voice != nil && isGuardrailRefusal(error) {
            // Measured on an iPhone 18 Pro Max: "May contain unsafe content" in 0.3 s for a creator whose typed "never write" was a scam phrase.
            report(error, "script")
            request.voice = request.voice?.catalogOnly
            use = .catalogOnly
            script = try await draft(request, [])
        }
        script.voiceUse = use
        let violations = violations(in: script, for: request)
        // What was only measured from their writing is counted and told to a second attempt that happens anyway, never the reason for one.
        guard violations.contains(where: { !$0.isSoft }), script.usedLanguageModel else {
            script.voiceViolations = violations.map(\.kind)
            return script
        }
        do {
            var second = try await draft(request, violations)
            let remaining = self.violations(in: second, for: request)
            TelemetryManager.record(VoiceCheckReport(first: violations.map(\.kind), remaining: remaining.map(\.kind), use: use))
            if remaining.count <= violations.count {
                second.attempts = 2
                second.voiceViolations = remaining.map(\.kind)
                second.voiceUse = use
                return second
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            report(error, "script.voiceRetry")
        }
        script.voiceViolations = violations.map(\.kind)
        return script
    }

    private func violations(in script: GeneratedScript, for request: ScriptRequest) -> [VoiceViolation] {
        VoiceConstraintChecker.violations(
            in: script.text, voice: request.voice, language: request.language,
            minimumWords: ReadTime.words(for: request.targetRange.lowerBound)
        )
    }
}
