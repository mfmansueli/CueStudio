//
//  UltraScriptService.swift
//  Cue Studio
//

import Foundation
import os

/// AI Scripts Ultra: a developed draft from Google's Gemini, then its polish in the creator's way of speaking, two calls through Firebase
/// (`UltraModelClient`). Apple Intelligence stays the default and is never replaced or fallen back from: a script is written here only when the
/// creator chose Ultra for it, and only with their permission (`UltraConsentService`). Before every call it asks again whether it may go out
/// (permission, the lab's cap, cancellation), so a revoked permission or a Stop never lets the next call leave. Only the polished script comes
/// back; a failed polish is a failure, with the draft kept apart in the error (`UltraError.reviewFailed`), never handed over as the script.
/// Nothing of the request, the voice or the answer is logged or sent to Analytics or Crashlytics: the Console hears kinds, times and token counts.
@MainActor
@Observable
final class UltraScriptService: UltraScriptWriting {
    /// Two calls per script: the draft and its polish.
    static let callsPerScript = 2

    let consent: UltraConsentService
    let budget: UltraCallBudget
    /// The creator's scripts left (the preview of the free ones and Pro's), spent by `generate` once a script is written; nil counts nothing (the
    /// lab, tests).
    let allowance: UltraAllowanceService?
    /// The invitation to try Ultra; nil shows none.
    let invite: UltraInviteService?
    /// Ultra is in this build and set up on this iPhone; read without touching the network.
    let isAvailable: Bool
    /// Makes the client the first time a script is written: nothing about Firebase (not even App Check) starts before the creator allowed it.
    @ObservationIgnored private let makeClient: @MainActor () -> (any UltraModelClient)?
    @ObservationIgnored private var client: (any UltraModelClient)?
    @ObservationIgnored private let clock = ContinuousClock()
    private static let log = Logger(subsystem: "studio.cue", category: "Ultra")

    /// - Parameters:
    ///   - isAvailable: false when this build or this iPhone has no Ultra (Release, or no lab configuration): nothing about it is shown.
    ///   - makeClient: the Firebase client, made only when a permitted script is first written.
    init(
        isAvailable: Bool, consent: UltraConsentService, budget: UltraCallBudget, allowance: UltraAllowanceService? = nil,
        invite: UltraInviteService? = nil, makeClient: @escaping @MainActor () -> (any UltraModelClient)?
    ) {
        self.isAvailable = isAvailable
        self.consent = consent
        self.budget = budget
        self.allowance = allowance
        self.invite = invite
        self.makeClient = makeClient
    }

    /// With a client already made (tests, the UI tests' stub).
    convenience init(
        client: any UltraModelClient, consent: UltraConsentService, budget: UltraCallBudget, allowance: UltraAllowanceService? = nil,
        invite: UltraInviteService? = nil
    ) {
        self.init(isAvailable: true, consent: consent, budget: budget, allowance: allowance, invite: invite, makeClient: { client })
    }

    var isReady: Bool { isAvailable && consent.isGranted }

    var scriptsLeft: Int? { allowance?.left }

    var membership: UltraAllowance.Membership? { allowance?.allowance.membership }

    /// The invitation to try Ultra shows: it is offered here, not allowed yet, the creator used the AI before and hasn't closed it, and there are
    /// scripts to try it with.
    var showsInvite: Bool {
        guard isAvailable, !consent.isGranted, let invite, invite.isDue else { return false }
        return (scriptsLeft ?? 1) > 0
    }

    func noteAIUse() {
        invite?.noteAIUse()
    }

    /// A script for the creator: counted against their scripts once it is written, never when it failed or was stopped.
    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript {
        if let allowance, allowance.left == 0 { throw UltraError.noScriptsLeft }
        let script = try await run(request, reporting: meter).script
        allowance?.spend()
        return script
    }

    /// The whole run, for the lab: the polished script with its draft, the editor's changes and each call's numbers.
    /// - Parameter length: the lab's comparison overrides the request's own length policy; nil keeps it.
    func run(_ request: ScriptRequest, length: UltraLength? = nil, reporting meter: WritingProgressMeter? = nil) async throws -> UltraRun {
        guard isAvailable else { throw UltraError.notAvailable }
        try mayContinue(started: false)
        guard budget.allows(Self.callsPerScript) else { throw UltraError.budgetExhausted }
        guard let client = client ?? makeClient() else { throw UltraError.notAvailable }
        self.client = client
        let payload = UltraPayload(request, length: length)

        meter?.record(.drafting)
        let draftStart = clock.now
        let draftReply = try await call(client, payload.draft) { meter?.record(.wrote(words: $0)) }
        let draftSeconds = Self.seconds(draftStart.duration(to: clock.now))
        let draft = draftReply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draftReply.finishedNormally, !draft.isEmpty else {
            note("draft incomplete", reply: draftReply, seconds: draftSeconds)
            throw UltraError.draftFailed(.incomplete)
        }
        note("draft", reply: draftReply, seconds: draftSeconds)

        // The polish goes out only if the creator still lets it: Stop, Cancel or a revoked permission end the run here.
        try mayContinue(started: true)
        let draftWords = max(1, ReadTime.wordCount(in: draft))
        meter?.record(.lengthening(done: 0, of: draftWords))
        let reviewStart = clock.now
        let reviewReply: UltraModelReply
        do {
            reviewReply = try await call(client, payload.review(of: draft)) { meter?.record(.lengthening(done: min($0, draftWords), of: draftWords)) }
        } catch UltraError.draftFailed(let failure) {
            throw UltraError.reviewFailed(failure, draft: draft)
        }
        let reviewSeconds = Self.seconds(reviewStart.duration(to: clock.now))
        guard reviewReply.finishedNormally, let reply = UltraReviewReply(json: reviewReply.text) else {
            note("review incomplete", reply: reviewReply, seconds: reviewSeconds)
            throw UltraError.reviewFailed(.incomplete, draft: draft)
        }
        note("review", reply: reviewReply, seconds: reviewSeconds)
        // What arrived after a Stop or a revoked permission is not handed over.
        try mayContinue(started: true)

        let script = finished(reply, request: request)
        guard !script.text.isEmpty else { throw UltraError.reviewFailed(.incomplete, draft: draft) }
        return UltraRun(
            script: script, draft: draft, changes: reply.changes, draftSeconds: draftSeconds, reviewSeconds: reviewSeconds,
            draftReply: draftReply, reviewReply: reviewReply
        )
    }

    // MARK: - Steps

    /// Throws when nothing more may go out: the run was cancelled, or permission was never given (`started` false) or was taken back.
    private func mayContinue(started: Bool) throws {
        try Task.checkCancellation()
        guard consent.isGranted else { throw started ? UltraError.consentRevoked : UltraError.consentRequired }
    }

    /// One counted call. A call that can't be counted never goes out.
    private func call(
        _ client: any UltraModelClient, _ stage: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void
    ) async throws -> UltraModelReply {
        guard budget.reserve() else { throw UltraError.budgetExhausted }
        do {
            return try await client.generate(stage, progress: progress)
        } catch let error as CancellationError {
            throw error
        } catch let error as UltraError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            let failure = (error as? UltraClientError)?.failure ?? .provider
            Self.log.error("Ultra \(stage.stage.rawValue, privacy: .public) failed: \(failure.rawValue, privacy: .public)")
            throw UltraError.draftFailed(failure)
        }
    }

    /// The polished script, cleaned as Apple Intelligence's is (no markdown or dashes, the creator's literal words kept), always with the reminder
    /// to check facts: Ultra imagines for the creator and no step verifies a claim.
    private func finished(_ reply: UltraReviewReply, request: ScriptRequest) -> GeneratedScript {
        let language = request.language?.locale.language
        let protected = ScriptVerbatimProtection(reply.script, phrases: request.requiredPhrases)
        let text = protected.restoring(in: ScriptPromptBuilder.collapsingRepeatedSentences(
            ScriptPromptBuilder.clean(protected.text, language: language, preserving: request.preservedPhrases)
        ))
        var title = ScriptPromptBuilder.cleanTitle(reply.title, language: language, preserving: request.preservedPhrases)
        if title.isEmpty, case .prompt(let idea) = request.source {
            title = idea.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ")
        }
        return GeneratedScript(
            title: title, text: text, usedLanguageModel: true, needsFactCheck: true, model: nil, engine: .ultra,
            voiceUse: request.voice == nil ? .none : .full
        )
    }

    private func note(_ what: String, reply: UltraModelReply, seconds: Double) {
        let output = reply.outputTokens ?? -1, thinking = reply.thinkingTokens ?? -1
        Self.log.info(
            "Ultra \(what, privacy: .public): \(seconds, format: .fixed(precision: 1)) s, \(output) output and \(thinking) thinking tokens, \(self.budget.used) of \(self.budget.limit) calls"
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
