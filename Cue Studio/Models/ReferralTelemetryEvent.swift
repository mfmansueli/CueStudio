//
//  ReferralTelemetryEvent.swift
//  Cue Studio
//

import Foundation

/// One measured moment of the invites: where an invite was offered or opened, a code shared or typed (only whether it counted), a reward.
/// Sent only with "Help improve Cue" on; never the code, the install's id or anything the creator wrote.
nonisolated struct ReferralTelemetryEvent: Hashable, Sendable {
    enum Step: String, Sendable {
        /// An invite offered (`place`).
        case offered
        /// The invites page opened (`place`).
        case opened
        /// The code copied.
        case copied
        /// The message handed to the share sheet.
        case shared
        /// A friend's code typed (`outcome`).
        case joined
        /// Friends' first exports credited (`outcome`: exports or ultra; `count`).
        case rewarded
        /// Apple's rating prompt asked (iOS decides whether it shows).
        case reviewAsked = "review_asked"
    }

    /// Where an invite was offered or opened.
    enum Place: String, Identifiable, Sendable {
        /// "Ready to travel" with one free export left.
        case lastExport = "last_export"
        /// "Ready to travel" with none left.
        case exhausted
        /// "Your video is ready", when the free exports are gone.
        case exportReady = "export_ready"
        case profile
        /// A friend's first "Ready to travel": "Have a friend's code?".
        case firstExport = "first_export"

        var id: String { rawValue }
    }

    var step: Step
    var place: Place?
    var outcome: String?
    var count: Int?

    var parameters: [String: Any] {
        var parameters: [String: Any] = ["step": step.rawValue]
        if let place { parameters["place"] = place.rawValue }
        if let outcome { parameters["outcome"] = outcome }
        if let count { parameters["count"] = count }
        return parameters
    }
}
