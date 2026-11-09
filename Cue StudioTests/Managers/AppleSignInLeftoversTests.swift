//
//  AppleSignInLeftoversTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Sign in with Apple is gone (owner, 09/11/2026): the account it kept (Apple's user identifier, the name and email) goes at the first launch of
/// the new build, and the name the creator sees stays exactly as it is, still theirs to edit.
@MainActor
@Suite("Sign in with Apple leftovers")
struct AppleSignInLeftoversTests {
    /// The account as the removed `SessionService` wrote it.
    private func storeOldAccount(in defaults: UserDefaults) throws {
        let account = ["userID": "001234.abcdef", "name": "Maya Reyes", "email": "maya@privaterelay.appleid.com"]
        defaults.set(try JSONEncoder().encode(account), forKey: DefaultsKey.legacyAppleAccount)
    }

    @Test func theAccountGoesAndTheVisibleNameStays() throws {
        let store = TestDefaults()
        defer { store.tearDown() }
        let profile = CreatorProfileService(defaults: store.defaults)
        profile.profile.name = "Maya R."
        try storeOldAccount(in: store.defaults)

        AppleSignInLeftovers.erase(from: store.defaults)

        #expect(store.defaults.object(forKey: DefaultsKey.legacyAppleAccount) == nil)
        let relaunched = CreatorProfileService(defaults: store.defaults)
        #expect(relaunched.profile.name == "Maya R.", "the name the creator sees, not the one Apple shared")
        relaunched.profile.name = "Maya"
        #expect(CreatorProfileService(defaults: store.defaults).profile.name == "Maya")
    }

    /// A creator who signed in with an empty profile name sees no name before and after: nothing is filled from the account on the way out.
    @Test func anEmptyNameStaysEmpty() throws {
        let store = TestDefaults()
        defer { store.tearDown() }
        try storeOldAccount(in: store.defaults)

        AppleSignInLeftovers.erase(from: store.defaults)

        #expect(CreatorProfileService(defaults: store.defaults).profile.name.isEmpty)
        #expect(store.defaults.object(forKey: DefaultsKey.legacyAppleAccount) == nil)
    }

    /// Every later launch finds nothing and changes nothing.
    @Test func laterLaunchesChangeNothing() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let profile = CreatorProfileService(defaults: store.defaults)
        profile.profile.name = "Maya"
        AppleSignInLeftovers.erase(from: store.defaults)
        AppleSignInLeftovers.erase(from: store.defaults)
        #expect(CreatorProfileService(defaults: store.defaults).profile.name == "Maya")
    }
}
