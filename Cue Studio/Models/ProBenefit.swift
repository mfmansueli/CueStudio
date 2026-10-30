//
//  ProBenefit.swift
//  Cue Studio
//

import Foundation

/// A plain line of what Pro offers (11.4), under its two highlights.
nonisolated struct ProBenefit: Sendable {
    let text: String
    /// About Apple Intelligence: left out where it can't run.
    var needsAppleIntelligence = false
    /// False for a line the board lists that the app cannot do yet: it stays out of the paywall until it can, so the paywall never sells what is not there.
    var isAvailable = true
}
