//
//  AppleAccount.swift
//  Cue Studio
//

import Foundation

/// Who signed in with Apple. Apple shares the name and email only the first time, so they are
/// kept on the device. There is no Cue server: the account only personalizes the profile.
nonisolated struct AppleAccount: Codable, Hashable, Sendable {
    /// Apple's stable user identifier for this app.
    var userID: String
    var name: String?
    var email: String?
}
