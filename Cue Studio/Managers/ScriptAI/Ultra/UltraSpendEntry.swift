//
//  UltraSpendEntry.swift
//  Cue Studio
//

import Foundation

/// One Ultra request from this iPhone and what it spent: a script (its two or three calls, and the fit that followed by itself when it came back
/// past its range) or a fit the creator asked for. Unfinished when it failed or was stopped after some calls went out: those were spent too.
nonisolated struct UltraSpendEntry: Hashable, Sendable, Codable {
    enum Kind: String, Hashable, Sendable, Codable {
        case script, fit
    }

    var kind: Kind
    var date: Date
    var cost: UltraCost
    var finished: Bool
}
