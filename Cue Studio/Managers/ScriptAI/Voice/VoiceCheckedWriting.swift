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
/// - If a voice correction fails or loses useful content (`RevisionChoice`), the first script stands.
/// - Explicit verbatim wording is a delivery requirement: if neither attempt keeps it, report a clear error instead of delivering a changed phrase.
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
            return try checked(script, for: request)
        }
        do {
            var second = try await draft(request, violations)
            let remaining = self.violations(in: second, for: request)
            // The second draft is kept only when what it breaks is less serious and it lost nothing that made the first worth having.
            let verdict = RevisionChoice.verdict(
                original: DraftAssessment(text: script.text, violations: violations, request: request),
                revision: DraftAssessment(text: second.text, violations: remaining, request: request)
            )
            TelemetryManager.record(VoiceCheckReport(first: violations.map(\.kind), remaining: remaining.map(\.kind), use: use, verdict: verdict))
            if verdict.takesRevision {
                second.attempts = 2
                second.voiceViolations = remaining.map(\.kind)
                second.voiceUse = use
                second.discardedDraft = script.text
                return try checked(second, for: request)
            }
            script.discardedDraft = second.text
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            report(error, "script.voiceRetry")
        }
        script.voiceViolations = violations.map(\.kind)
        return try checked(script, for: request)
    }

    private func checked(_ script: GeneratedScript, for request: ScriptRequest) throws -> GeneratedScript {
        var script = script
        // A result nobody gave that is still there after the second attempt: the creator is asked to check before they say it.
        if script.voiceViolations.contains(.inventedResult) { script.needsFactCheck = true }
        guard !ScriptVerbatimSlots(phrases: request.requiredPhrases).hasUnresolvedMarker(in: script.text),
              request.requiredPhrases.allSatisfy({ ScriptVerbatimRequirements.contains($0, in: script.text) }) else {
            throw ScriptAIError.requiredWording
        }
        return script
    }

    func violations(in script: GeneratedScript, for request: ScriptRequest) -> [VoiceViolation] {
        // A serious statement is checked against the voice's rules alone (`ScriptRequest.rules`).
        let voice = VoiceConstraintChecker.violations(
            in: script.text, voice: request.voice ?? request.rules, language: request.language,
            minimumWords: request.durationPolicy == .targeted ? ReadTime.words(for: request.targetRange.lowerBound, language: request.language) : 0,
            openingLine: request.brief?.openingLine, request: request.creatorText
        )
        let required = request.requiredPhrases.filter { !ScriptVerbatimRequirements.contains($0, in: script.text) }.map {
            VoiceViolation(kind: .requiredPhrase, detail: "Include this exact text unchanged in a spoken block, including capitalization and punctuation: “\($0)”")
        }
        // A free request can intentionally change perspective (a team statement, a POV scene).
        // Profile pronouns remain in the prompt, but cannot force a correction that changes who did what.
        let unresolved = ScriptVerbatimSlots(phrases: request.requiredPhrases).hasUnresolvedMarker(in: script.text)
            ? [VoiceViolation(kind: .requiredPhrase, detail: "Replace any incomplete exact-wording marker with its complete assigned phrase, unchanged.")] : []
        let applicable = voice.filter { !(request.modelRoute == .privateCloud && $0.kind == .pronoun) }
        return applicable + required + unresolved + inventedResults(in: script, for: request) + agreement(in: script, for: request)
    }

    /// The gender they chose, kept (the owner's B8; §11.7): a word about them in the other one is written once more.
    private func agreement(in script: GeneratedScript, for request: ScriptRequest) -> [VoiceViolation] {
        guard let theirs = request.voice ?? request.rules else { return [] }
        let found = GenderAgreementChecker.findings(
            in: script.text, agreement: theirs.agreement, speaksAs: theirs.resolvedSpeaksAs, language: AgreementGuide.code(of: request)
        )
        guard !found.isEmpty else { return [] }
        let words = found.map { "“\($0)”" }.joined(separator: ", ")
        let wanted = switch theirs.resolvedSpeaksAs == .we ? theirs.agreement.group : theirs.agreement.speaker {
        case .feminine?: "the feminine"
        case .masculine?: "the masculine"
        default: "wording that marks no gender"
        }
        return [VoiceViolation(kind: .agreement, detail: "It says \(words) about the creator: use \(wanted) for every word about them.")]
    }

    /// A result put in the creator's mouth that their idea doesn't give, with or without a voice (the owner's B12; §11, A11b): written once
    /// more, and the page asks to check the facts if it stays (`checked`).
    private func inventedResults(in script: GeneratedScript, for request: ScriptRequest) -> [VoiceViolation] {
        AttributedResultDetector.findings(in: script.text, language: request.language?.locale.identifier, request: request.creatorText).map {
            VoiceViolation(
                kind: .inventedResult,
                detail: "It says “\($0)”, a result the idea doesn't give: never invent a result (weight, money, percentages, gains, cures), "
                    + "a statistic, a price or a credential for the creator."
            )
        }
    }
}
