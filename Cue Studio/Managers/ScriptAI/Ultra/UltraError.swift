//
//  UltraError.swift
//  Cue Studio
//

import Foundation

/// Why an Ultra script didn't arrive, in words the creator can act on. None of them carries the request, the voice or the model's answer, except
/// `reviewFailed`, which keeps the unpolished draft in memory for the lab to show as a draft (never saved or shown as a finished script).
nonisolated enum UltraError: LocalizedError, Equatable, Sendable {
    /// The lab isn't set up on this iPhone (no configuration), or this build has no Ultra.
    case notAvailable
    /// The creator hasn't allowed Google processing.
    case consentRequired
    /// Permission was taken back while the script was being written: the next call never went out.
    case consentRevoked
    /// The lab's calls are used up (`UltraCallBudget`).
    case budgetExhausted
    /// The creator's Ultra AI scripts are used up (`UltraAllowanceService`): nothing was sent.
    case noScriptsLeft
    /// The first call failed: no draft exists.
    case draftFailed(UltraFailure)
    /// The draft was written but its polish failed: there is no finished script.
    case reviewFailed(UltraFailure, draft: String)
    /// "Fit to time" failed: the script on the page is as it was.
    case fitFailed(UltraFailure)

    var errorDescription: String? {
        switch self {
        case .notAvailable: String(localized: "Ultra AI isn’t set up on this iPhone")
        case .consentRequired: String(localized: "Allow Ultra AI first · Privacy & AI data")
        case .consentRevoked: String(localized: "Ultra AI was turned off · Nothing more was sent")
        case .budgetExhausted: String(localized: "Ultra AI’s test calls are used up")
        case .noScriptsLeft: String(localized: "Your Ultra AI scripts are used up")
        case .draftFailed(.unreachable): String(localized: "Ultra AI needs the internet · Try again")
        case .draftFailed: String(localized: "Ultra AI couldn’t draft it")
        case .reviewFailed: String(localized: "Ultra AI couldn’t polish the draft")
        case .fitFailed(.unreachable): String(localized: "Ultra AI needs the internet · Try again")
        case .fitFailed: String(localized: "Ultra AI couldn’t fit it to the time")
        }
    }

    /// Asking again may well work: the call failed for a reason of its own (it took too long, stopped early, the provider was busy), not the
    /// network (the toast says so), the setup or a filter, which the same call would meet again. Where the page is still there, the toast
    /// carries "Try again" (`ScriptFailureNotice`).
    var isWorthRetrying: Bool {
        switch self {
        case .draftFailed(let failure), .reviewFailed(let failure, _), .fitFailed(let failure):
            [.timedOut, .incomplete, .provider].contains(failure)
        case .notAvailable, .consentRequired, .consentRevoked, .budgetExhausted, .noScriptsLeft: false
        }
    }
}
