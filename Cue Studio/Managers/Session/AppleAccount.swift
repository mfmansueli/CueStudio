//
//  AppleAccount.swift
//  Cue Studio
//

import Foundation

/// Who signed in with Apple. Apple shares the name and email only the first time, so they are
/// kept on the device. Cue's server never sees it (it knows Ultra AI's calls and the invites' random install id, never an account): the
/// account only personalizes the profile.
nonisolated struct AppleAccount: Codable, Hashable, Sendable {
    /// Apple's stable user identifier for this app.
    var userID: String
    var name: String?
    var email: String?
}
