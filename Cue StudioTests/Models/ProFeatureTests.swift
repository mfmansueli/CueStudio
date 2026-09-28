//
//  ProFeatureTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ProFeature")
struct ProFeatureTests {
    @Test func theFreePlanUnlocksNoneOfThem() {
        #expect(ProFeature.allCases.allSatisfy { !$0.isUnlocked(for: .free) })
    }

    @Test func subscriptionsAndLifetimeUnlockEverything() {
        #expect(ProFeature.allCases.allSatisfy { $0.isUnlocked(for: .subscriber) })
        #expect(ProFeature.allCases.allSatisfy { $0.isUnlocked(for: .lifetime) })
    }
}
