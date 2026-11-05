//
//  ReferralStateStoring.swift
//  Cue Studio
//

import Foundation

protocol ReferralStateStoring: AnyObject {
    /// Nil when nothing was saved yet; throws when it couldn't be read (the Keychain before the first unlock), which is not the same.
    func load() throws -> ReferralLocalState?
    func save(_ state: ReferralLocalState)
}
