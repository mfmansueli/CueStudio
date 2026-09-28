//
//  SessionServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("SessionService")
struct SessionServiceTests {
    @Test func signingInIsRemembered() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let session = SessionService(defaults: store.defaults, checker: FakeCredentialChecker())
        session.signIn(userID: "apple-1", name: "Maya Reyes", email: "maya@example.com")
        let relaunched = SessionService(defaults: store.defaults, checker: FakeCredentialChecker())
        #expect(relaunched.account == AppleAccount(userID: "apple-1", name: "Maya Reyes", email: "maya@example.com"))
    }

    @Test func laterSignInsKeepTheNameAppleSentFirst() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let session = SessionService(defaults: store.defaults, checker: FakeCredentialChecker())
        session.signIn(userID: "apple-1", name: "Maya Reyes", email: nil)
        session.signIn(userID: "apple-1", name: nil, email: nil)
        #expect(session.account?.name == "Maya Reyes")
    }

    @Test func signingOutForgetsTheAccount() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let session = SessionService(defaults: store.defaults, checker: FakeCredentialChecker())
        session.signIn(userID: "apple-1", name: nil, email: nil)
        session.signOut()
        #expect(!session.isSignedIn)
        #expect(!SessionService(defaults: store.defaults, checker: FakeCredentialChecker()).isSignedIn)
    }

    @Test func aRevokedAccountIsSignedOutAtLaunch() async {
        let store = TestDefaults()
        defer { store.tearDown() }
        let checker = FakeCredentialChecker()
        let session = SessionService(defaults: store.defaults, checker: checker)
        session.signIn(userID: "apple-1", name: nil, email: nil)
        checker.revoked = true
        await session.verify()
        #expect(!session.isSignedIn)
    }

    @Test func aValidAccountStaysSignedIn() async {
        let store = TestDefaults()
        defer { store.tearDown() }
        let session = SessionService(defaults: store.defaults, checker: FakeCredentialChecker())
        session.signIn(userID: "apple-1", name: nil, email: nil)
        await session.verify()
        #expect(session.isSignedIn)
    }
}
