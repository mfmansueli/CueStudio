//
//  UltraScriptService.swift
//  Cue Studio
//

import Foundation
import os

/// AI Scripts Ultra: a developed draft from Google's Gemini, then (`UltraFlow.checked`) its claims checked on their own, then its polish in the
/// creator's way of speaking, two or three calls through Firebase (`UltraModelClient`). Apple Intelligence stays the default and is never
/// replaced or fallen back from: a script is written here only when the creator chose Ultra for it, and only with their permission
/// (`UltraConsentService`). Before every call it asks again whether it may go out (permission, the lab's cap, cancellation), so a revoked
/// permission or a Stop never lets the next call leave. Only the polished script comes back; a failed check or polish is a failure, with the
/// draft kept apart in the error (`UltraError.reviewFailed`), never handed over as the script.
/// Nothing of the request, the voice or the answer is logged or sent to Analytics or Crashlytics: the Console hears kinds, times and token counts.
/// What each script and fit cost, in Google's token counts, goes to the lab's ledger (`UltraSpendLedger`), failed and stopped ones included.
@MainActor
@Observable
final class UltraScriptService: UltraScriptWriting {
    /// The passes a script goes through when the caller doesn't say (the lab and the comparison pick their own). The check is in: in the blind
    /// comparison of 29/10/2026 (15 ideas, two judges, `tools/ultra/compare.py`) the checked script won all 6 pairs against the unchecked one,
    /// its accuracy 4.3 to 4.6 out of 5 against 3.2 to 3.5, and all 15 against Apple Intelligence.
    var flow = UltraFlow.checked

    let consent: UltraConsentService
    let budget: UltraCallBudget
    /// The creator's scripts left (the preview of the free ones and Pro's), spent by `generate` once a script is written; nil counts nothing (the
    /// lab, tests).
    let allowance: UltraAllowanceService?
    /// The invitation to try Ultra; nil shows none.
    let invite: UltraInviteService?
    /// What each request spent; nil keeps no record (tests that don't look at it).
    let spend: UltraSpendLedger?
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
        invite: UltraInviteService? = nil, spend: UltraSpendLedger? = nil, makeClient: @escaping @MainActor () -> (any UltraModelClient)?
    ) {
        self.isAvailable = isAvailable
        self.consent = consent
        self.budget = budget
        self.allowance = allowance
        self.invite = invite
        self.spend = spend
        self.makeClient = makeClient
    }

    /// With a client already made (tests, the UI tests' stub).
    convenience init(
        client: any UltraModelClient, consent: UltraConsentService, budget: UltraCallBudget, allowance: UltraAllowanceService? = nil,
        invite: UltraInviteService? = nil, spend: UltraSpendLedger? = nil
    ) {
        self.init(isAvailable: true, consent: consent, budget: budget, allowance: allowance, invite: invite, spend: spend, makeClient: { client })
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
    /// - Parameters:
    ///   - length: the lab's comparison overrides the request's own length policy; nil keeps it.
    ///   - flow: the passes; nil is `flow`.
    func run(
        _ request: ScriptRequest, length: UltraLength? = nil, flow: UltraFlow? = nil, reporting meter: WritingProgressMeter? = nil
    ) async throws -> UltraRun {
        let flow = flow ?? self.flow
        guard isAvailable else { throw UltraError.notAvailable }
        try mayContinue(started: false)
        guard budget.allows(flow.calls) else { throw UltraError.budgetExhausted }
        guard let client = client ?? makeClient() else { throw UltraError.notAvailable }
        self.client = client
        let payload = UltraPayload(request, length: length)
        // Every call that goes out is spent, whether the script comes back or not.
        var cost = UltraCost()
        var done = false
        defer { record(.script, cost: cost, finished: done) }

        meter?.record(.drafting)
        meter?.begin(pass: 0, of: flow.calls)
        let draftStart = clock.now
        let draftReply = try await call(client, payload.draft, cost: &cost) { words in
            meter?.record(.wrote(words: words))
            meter?.advance(pass: Double(words) / Double(meter?.expectedWords ?? 1))
        }
        let draftSeconds = Self.seconds(draftStart.duration(to: clock.now))
        let draft = draftReply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draftReply.finishedNormally, !draft.isEmpty else {
            note("draft incomplete", reply: draftReply, seconds: draftSeconds)
            throw UltraError.draftFailed(.incomplete)
        }
        note("draft", reply: draftReply, seconds: draftSeconds)

        // The check and the polish go out only if the creator still lets them: Stop, Cancel or a revoked permission end the run here.
        let draftWords = max(1, ReadTime.wordCount(in: draft))
        let total = draftWords * (flow == .checked ? 2 : 1)
        var check: (reply: UltraCheckReply, seconds: Double, call: UltraModelReply)?
        if flow == .checked {
            check = try await checked(draft, payload: payload, client: client, words: draftWords, of: total, cost: &cost, meter)
        }

        try mayContinue(started: true)
        let before = total - draftWords
        meter?.record(.lengthening(done: before, of: total))
        meter?.begin(pass: flow.calls - 1, of: flow.calls)
        let reviewStart = clock.now
        let reviewReply: UltraModelReply
        do {
            let stage = payload.review(of: check?.reply.script ?? draft, corrections: check?.reply.corrections)
            reviewReply = try await call(client, stage, cost: &cost) {
                meter?.record(.lengthening(done: before + min($0, draftWords), of: total))
                meter?.advance(pass: Double($0) / Double(draftWords))
            }
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

        var script = finished(reply, request: request)
        guard !script.text.isEmpty else { throw UltraError.reviewFailed(.incomplete, draft: draft) }
        // A vertical video that came back past its range (a little over it, never past two minutes) is fitted into it, one more call. A fit
        // that fails or may not go out leaves the polished script.
        if case .ideal(let range) = payload.length, let limit = payload.length.overflowWords, ReadTime.wordCount(in: script.text) > limit,
           let shorter = try? await fitted(UltraFitRequest(
               script: script.text, platform: request.platform, range: range, voice: request.voice, language: request.language?.locale.language
           ), cost: &cost), !shorter.isEmpty {
            script.text = shorter
        }
        done = true
        return UltraRun(
            script: script, draft: draft, changes: reply.changes, draftSeconds: draftSeconds, reviewSeconds: reviewSeconds,
            draftReply: draftReply, reviewReply: reviewReply, flow: flow, checked: check?.reply.script, corrections: check?.reply.corrections ?? [],
            checkSeconds: check?.seconds, checkReply: check?.call, cost: cost
        )
    }

    /// The claim check (`UltraFlow.checked`): the draft with its claims corrected, or a failure that keeps the draft apart.
    private func checked(
        _ draft: String, payload: UltraPayload, client: any UltraModelClient, words: Int, of total: Int, cost: inout UltraCost,
        _ meter: WritingProgressMeter?
    ) async throws -> (reply: UltraCheckReply, seconds: Double, call: UltraModelReply) {
        try mayContinue(started: true)
        meter?.record(.lengthening(done: 0, of: total))
        meter?.begin(pass: 1, of: UltraFlow.checked.calls)
        let start = clock.now
        let answer: UltraModelReply
        do {
            answer = try await call(client, payload.check(of: draft), cost: &cost) {
                meter?.record(.lengthening(done: min($0, words), of: total))
                meter?.advance(pass: Double($0) / Double(words))
            }
        } catch UltraError.draftFailed(let failure) {
            throw UltraError.reviewFailed(failure, draft: draft)
        }
        let seconds = Self.seconds(start.duration(to: clock.now))
        guard answer.finishedNormally, let reply = UltraCheckReply(json: answer.text) else {
            note("check incomplete", reply: answer, seconds: seconds)
            throw UltraError.reviewFailed(.incomplete, draft: draft)
        }
        note("check", reply: answer, seconds: seconds)
        return (reply, seconds, answer)
    }

    /// "Fit to time" for a script Ultra wrote: one call, counted like the others, only with permission and never after a Stop. The fitted
    /// speech, cleaned as a script is; a failure leaves the page as it was. A script already in the range comes back as it is, with no call.
    func fit(_ request: UltraFitRequest) async throws -> String {
        var cost = UltraCost()
        var done = false
        defer { record(.fit, cost: cost, finished: done) }
        let script = try await fitted(request, cost: &cost)
        done = true
        return script
    }

    /// The fit's one call, its cost added to `cost` (the creator's fit, or the one that follows a script past its range by itself).
    private func fitted(_ request: UltraFitRequest, cost: inout UltraCost) async throws -> String {
        guard !request.words.contains(ReadTime.wordCount(in: request.script)) else { return request.script }
        guard isAvailable else { throw UltraError.notAvailable }
        try mayContinue(started: false)
        guard budget.allows(1) else { throw UltraError.budgetExhausted }
        guard let client = client ?? makeClient() else { throw UltraError.notAvailable }
        self.client = client
        let start = clock.now
        let reply: UltraModelReply
        do {
            reply = try await call(client, request.stage, cost: &cost) { _ in }
        } catch UltraError.draftFailed(let failure) {
            throw UltraError.fitFailed(failure)
        }
        let seconds = Self.seconds(start.duration(to: clock.now))
        guard reply.finishedNormally, let answer = UltraFitReply(json: reply.text) else {
            note("fit incomplete", reply: reply, seconds: seconds)
            throw UltraError.fitFailed(.incomplete)
        }
        note("fit", reply: reply, seconds: seconds)
        try mayContinue(started: true)
        return ScriptParagraphs.arranged(
            ScriptPromptBuilder.collapsingRepeatedSentences(ScriptPromptBuilder.clean(answer.script, language: request.language))
        )
    }

    // MARK: - Steps

    /// Throws when nothing more may go out: the run was cancelled, or permission was never given (`started` false) or was taken back.
    private func mayContinue(started: Bool) throws {
        try Task.checkCancellation()
        guard consent.isGranted else { throw started ? UltraError.consentRevoked : UltraError.consentRequired }
    }

    /// One counted call, added to `cost` (with Google's usage when it answered). A call that can't be counted never goes out.
    private func call(
        _ client: any UltraModelClient, _ stage: UltraStageRequest, cost: inout UltraCost, progress: @escaping @MainActor (Int) -> Void
    ) async throws -> UltraModelReply {
        guard budget.reserve() else { throw UltraError.budgetExhausted }
        do {
            let reply = try await client.generate(stage, progress: progress)
            cost.add(reply)
            return reply
        } catch {
            // It went out: counted, with no usage to price.
            cost.add(nil)
            if error is CancellationError || error is UltraError { throw error }
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
        var title = UltraTitleAccents.restored(
            ScriptPromptBuilder.cleanTitle(reply.title, language: language, preserving: request.preservedPhrases), from: text
        )
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
        var cost = UltraCost()
        cost.add(reply)
        Self.log.info(
            "Ultra \(what, privacy: .public): \(seconds, format: .fixed(precision: 1)) s, \(output) output and \(thinking) thinking tokens, USD \(cost.dollars(), format: .fixed(precision: 4)), \(self.budget.used) of \(self.budget.limit) calls"
        )
    }

    /// The request's spend into the lab's ledger and the Console, when a call went out.
    private func record(_ kind: UltraSpendEntry.Kind, cost: UltraCost, finished: Bool) {
        guard cost.calls > 0 else { return }
        spend?.record(kind, cost: cost, finished: finished)
        Self.log.info(
            "Ultra \(kind.rawValue, privacy: .public)\(finished ? "" : " (unfinished)", privacy: .public): \(cost.calls) calls, \(cost.inputTokens) input, \(cost.outputTokens) output and \(cost.thinkingTokens) thinking tokens, USD \(cost.dollars(), format: .fixed(precision: 4))"
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
