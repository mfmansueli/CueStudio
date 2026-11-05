//
//  ReferralLocalState.swift
//  Cue Studio
//

import Foundation

/// What this iPhone keeps of the invites, in the Keychain so a reinstall keeps it (`KeychainReferralStateStore`): the install's random id (all
/// the server knows of it), the rewards already credited, the code it joined with as a friend, and the creator's last status.
nonisolated struct ReferralLocalState: Codable, Equatable, Sendable {
    /// Random, made on this iPhone the first time; never tied to a name, an account or the device.
    var installID: UUID
    var rewards = ReferralRewards()
    /// The code this install typed, as a friend.
    var joinedCode: String?
    /// A video of this iPhone left Cue (on any plan): a code can't be typed after that.
    var delivered = false
    /// The friend's first export reached the server.
    var activationSent = false
    /// The creator's own invites, as last read: shown at once, and the sign that this creator invites (only then does Cue ask the server).
    var status: ReferralStatus?
}
