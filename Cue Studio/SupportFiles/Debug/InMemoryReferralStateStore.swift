//
//  InMemoryReferralStateStore.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// The invites' state for UI tests, unit tests and previews: nothing reaches the Keychain.
final class InMemoryReferralStateStore: ReferralStateStoring {
    private(set) var state: ReferralLocalState?
    /// The Keychain before the first unlock.
    var isUnreadable = false

    init(state: ReferralLocalState? = nil) {
        self.state = state
    }

    func load() throws -> ReferralLocalState? {
        if isUnreadable { throw KeychainReferralStateStore.Unreadable() }
        return state
    }

    func save(_ state: ReferralLocalState) { self.state = state }
}
#endif
