//
//  AppleIDCredentialChecking.swift
//  Cue Studio
//

import Foundation

/// Asks Apple whether a signed-in account is still valid (revoked from Settings, for example).
/// Swappable so tests never talk to the system.
protocol AppleIDCredentialChecking: AnyObject {
    /// True only when Apple says the account was revoked or no longer exists; a check that can't
    /// be made (offline, say) keeps the creator signed in.
    func wasRevoked(userID: String) async -> Bool
}
