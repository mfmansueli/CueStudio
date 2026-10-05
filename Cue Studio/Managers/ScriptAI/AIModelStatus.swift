//
//  AIModelStatus.swift
//  Cue Studio
//

import Foundation

/// Where one Apple Intelligence model stands, apart from the languages it writes in.
nonisolated enum AIModelStatus: Equatable, Sendable {
    case available
    /// This device can't run Apple Intelligence.
    case deviceNotEligible
    /// Apple Intelligence is off in Settings.
    case turnedOff
    /// Supported and on, but the model is still downloading or getting ready.
    case preparing
    /// Private Cloud Compute only: this person's quota is used up for now.
    case quotaReached
}

nonisolated extension AIModelStatus {
    /// Why Apple Intelligence can't write, in words for the creator.
    var reason: String {
        switch self {
        case .available, .quotaReached:
            String(localized: "Apple Intelligence isn't available right now.")
        case .deviceNotEligible:
            String(localized: "Requires Apple Intelligence. This device doesn't support it.")
        case .turnedOff:
            String(localized: "Requires Apple Intelligence. Turn it on in Settings to use AI tools.")
        case .preparing:
            String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.")
        }
    }
}
