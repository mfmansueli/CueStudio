//
//  UltraScriptService.swift
//  Cue Studio
//

import Foundation
import os

/// AI Scripts Ultra: a developed draft from Claude through Cue's server (Gemini or Claude directly in the Debug lab), then
/// its polish in the creator's way of speaking, which also corrects its claims (`UltraFlow.standard`; the lab can check them in a call of
/// their own, `UltraFlow.checked`), two or three calls
/// (`UltraModelClient`). Apple Intelligence stays the default and is never
/// replaced or fallen back from: a script is written here only when the creator chose Ultra for it, and only with their permission
/// (`UltraConsentService`). Before every call it asks again whether it may go out (permission, the lab's cap, cancellation), so a revoked
/// permission or a Stop never lets the next call leave. Only the polished script comes back; a failed check or polish is a failure, with the
/// draft kept apart in the error (`UltraError.reviewFailed`), never handed over as the script.
/// Nothing of the request, the voice or the answer is logged or sent to Analytics or Crashlytics: the Console hears kinds, times and token counts.
/// What each script and fit cost, in Google's token counts, goes to the lab's ledger (`UltraSpendLedger`), failed and stopped ones included.
@MainActor
@Observable
final class UltraScriptService: UltraScriptWriting {
    /// The passes a script goes through when the caller doesn't say (the lab and the comparison pick their own).
    var flow = UltraFlow.standard
    /// How much the model thinks in every call (the lab's comparison picks its own). The model's own choice until a cheaper level is shown to
    /// write as well (`UltraThinking`).
    var thinking = UltraThinking.model

    let consent: UltraConsentService
    let budget: UltraCallBudget
    /// The creator's scripts left (the preview of the free ones and Pro's), spent by `generate` once a script is written; nil counts nothing (the
    /// lab, tests).
    let allowance: UltraAllowanceService?
    /// The invitation to try Ultra; nil shows none.
    let invite: UltraInviteService?
    /// What each request spent; nil keeps no record (tests that don't look at it).
    let spend: UltraSpendLedger?
    /// Who the calls are for, so Cue's server counts the creator's scripts (DESIGN_PROJECT §57); nil says nothing (tests, the lab's stub).
    @ObservationIgnored var callerSource: UltraCallerSource?
    /// Cue's server was asked what the creator has left in this launch (`refreshAllowance`).
    @ObservationIgnored private var askedServer = false
    /// Ultra is in this build and set up on this iPhone; read without touching the network. A TestFlight build turns it on shortly after
    /// launch (`becomeAvailable`, `UltraDistribution`).
    private(set) var isAvailable: Bool
    /// Makes the client the first time a script is written: nothing about Firebase (not even App Check) starts before the creator allowed it.
    @ObservationIgnored private let makeClient: @MainActor () -> (any UltraModelClient)?
    @ObservationIgnored private var client: (any UltraModelClient)?
    @ObservationIgnored private let clock = ContinuousClock()
    private static let log = Logger(subsystem: "studio.cue", category: "Ultra")

    /// - Parameters:
    ///   - isAvailable: false when this launch has no Ultra (yet): nothing about it is shown.
    ///   - makeClient: the client (Cue's server, or the lab's in Debug), made only when a permitted script is first written.
    ///   - checksDistribution: a Release build asks StoreKit whether it is TestFlight's and offers Ultra if so (`UltraDistribution`).
    init(
        isAvailable: Bool, checksDistribution: Bool = false, consent: UltraConsentService, budget: UltraCallBudget,
        allowance: UltraAllowanceService? = nil, invite: UltraInviteService? = nil, spend: UltraSpendLedger? = nil,
        makeClient: @escaping @MainActor () -> (any UltraModelClient)?
    ) {
        self.isAvailable = isAvailable
        self.consent = consent
        self.budget = budget
        self.allowance = allowance
        self.invite = invite
        self.spend = spend
        self.makeClient = makeClient
        if checksDistribution {
            Task { [weak self] in
                if await UltraDistribution.allowsUltra() { self?.becomeAvailable() }
            }
        }
    }

    /// With a client already made (tests, the UI tests' stub).
    convenience init(
        client: any UltraModelClient, consent: UltraConsentService, budget: UltraCallBudget, allowance: UltraAllowanceService? = nil,
        invite: UltraInviteService? = nil, spend: UltraSpendLedger? = nil
    ) {
        self.init(isAvailable: true, consent: consent, budget: budget, allowance: allowance, invite: invite, spend: spend, makeClient: { client })
    }

    /// Offers Ultra from now on (a TestFlight build, once StoreKit says it isn't the App Store's).
    func becomeAvailable() {
        isAvailable = true
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

    /// A script for the creator: counted against their scripts once it is written, never when it failed or was stopped. Where Cue's server
    /// enforces the count, it is asked first in each launch, and again after each script (its answer is what the creator sees).
    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript {
        if allowance != nil, !askedServer { await refreshAllowance() }
        if let allowance, allowance.left == 0 { throw UltraError.noScriptsLeft }
        do {
            let script = try await run(request, reporting: meter).script
            allowance?.spend()
            Task { [weak self] in await self?.refreshAllowance() }
            return script
        } catch UltraError.noScriptsLeft {
            await refreshAllowance()
            throw UltraError.noScriptsLeft
        }
    }

    /// Asks Cue's server what the creator has left; its count replaces this iPhone's only while the server enforces one (`ULTRA_METERING`).
    /// Only with permission, since the client starts Firebase: nothing about it runs before the creator allowed Ultra AI.
    func refreshAllowance() async {
        guard isReady, let allowance, let callerSource, let made = client ?? makeClient() else { return }
        client = made
        guard let reporter = made as? UltraAllowanceReporting else { return }
        askedServer = true
        let caller = UltraCaller(installID: callerSource.installID(), proof: await callerSource.proof())
        guard caller.installID != nil, let answer = try? await reporter.allowance(for: caller) else { return }
        allowance.server = answer.allowance
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
        // One id for the draft, the check and the polish, so the server charges the script once.
        let caller = await caller(runID: UUID())
        // Every call that goes out is spent, whether the script comes back or not.
        var cost = UltraCost()
        var done = false
        defer { record(.script, cost: cost, finished: done) }

        meter?.record(.drafting)
        meter?.begin(pass: 0, of: flow.calls)
        let draftStart = clock.now
        let draftReply = try await call(client, payload.draft, for: caller, cost: &cost) { words in
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
            check = try await checked(draft, payload: payload, via: (client, caller), words: draftWords, of: total, cost: &cost, meter)
        }

        try mayContinue(started: true)
        let before = total - draftWords
        meter?.record(.lengthening(done: before, of: total))
        meter?.begin(pass: flow.calls - 1, of: flow.calls)
        let reviewStart = clock.now
        let reviewReply: UltraModelReply
        do {
            let stage = payload.review(of: check?.reply.script ?? draft, corrections: check?.reply.corrections)
            reviewReply = try await call(client, stage, for: caller, cost: &cost) {
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
        // A script that came back past its range (a little over a short one, never past the top of 2:30) is fitted into it, one more call. A
        // fit that fails or may not go out leaves the polished script.
        if case .ideal(let range) = payload.length, let limit = payload.length.overflowWords(in: request.language), ReadTime.wordCount(in: script.text) > limit,
           let shorter = try? await fitted(UltraFitRequest(
               script: script.text, platform: request.platform, range: range, voice: request.voice ?? request.rules,
               language: request.language?.locale.language, brand: request.brand
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
        _ draft: String, payload: UltraPayload, via route: (client: any UltraModelClient, caller: UltraCaller), words: Int, of total: Int,
        cost: inout UltraCost, _ meter: WritingProgressMeter?
    ) async throws -> (reply: UltraCheckReply, seconds: Double, call: UltraModelReply) {
        try mayContinue(started: true)
        meter?.record(.lengthening(done: 0, of: total))
        meter?.begin(pass: 1, of: UltraFlow.checked.calls)
        let start = clock.now
        let answer: UltraModelReply
        do {
            answer = try await call(route.client, payload.check(of: draft), for: route.caller, cost: &cost) {
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

    /// The fit stage alone (one call, counted like the others, only with permission and never after a Stop), for the device measurements
    /// (`UltraQualityDeviceTests`, `UltraCostDeviceTests`) and its tests. The app fits only a script that came back past its range, inside
    /// `run`: Fit to time on the page is Apple Intelligence's (owner, 01/11/2026: Ultra writes, it never touches up). A script already in the range
    /// comes back as it is, with no call.
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
            reply = try await call(client, request.stage, for: await caller(runID: nil), cost: &cost) { _ in }
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

    /// Who a call is for: the install, the run (nil for a fit, which no script holds) and the Pro proof.
    private func caller(runID: UUID?) async -> UltraCaller {
        guard let callerSource else { return UltraCaller() }
        return UltraCaller(installID: callerSource.installID(), runID: runID, proof: await callerSource.proof())
    }

    /// One counted call, added to `cost` (with Google's usage when it answered). A call that can't be counted never goes out. Cue's server's
    /// own refusals (no scripts left, the day's budget, the hourly ceiling) end the run with their own words, whatever the stage.
    private func call(
        _ client: any UltraModelClient, _ stage: UltraStageRequest, for caller: UltraCaller, cost: inout UltraCost,
        progress: @escaping @MainActor (Int) -> Void
    ) async throws -> UltraModelReply {
        guard budget.reserve() else { throw UltraError.budgetExhausted }
        var stage = stage
        stage.thinking = thinking
        stage.caller = caller
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
            switch failure {
            case .outOfScripts: throw UltraError.noScriptsLeft
            case .paused: throw UltraError.paused
            case .limited: throw UltraError.limited
            default: throw UltraError.draftFailed(failure)
            }
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
        // A script from an idea keeps the idea's title, the one the creator picked on the card (`UltraPayload.keptTitleLine`).
        if let kept = request.ideaTitle { title = kept }
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
