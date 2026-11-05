//
//  UltraCaller.swift
//  Cue Studio
//

import Foundation

/// Who an Ultra AI call is for, so Cue's server can count the creator's scripts (DESIGN_PROJECT §57): the install's random id (the one the
/// invites use, kept in the Keychain), the run's id (the same for the draft, the check and the polish of one script, nil for a fit), and on Cue
/// Pro the App Store's signed transaction, which the server checks with Apple. No name, account or contact; the lab's own providers ignore it.
nonisolated struct UltraCaller: Hashable, Sendable {
    var installID: UUID?
    var runID: UUID?
    var proof: String?
}
