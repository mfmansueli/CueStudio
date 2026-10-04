//
//  StoreErrorMessageTests.swift
//  Cue StudioTests
//

import Foundation
import StoreKit
import Testing
@testable import Cue_Studio

@Suite("Store error messages (04 · F7)")
struct StoreErrorMessageTests {
    @Test func noInternetIsCantReachTheAppStore() {
        #expect(StoreManager.message(for: URLError(.notConnectedToInternet)) == "Can't reach the App Store")
        #expect(StoreManager.message(for: StoreKitError.networkError(URLError(.timedOut))) == "Can't reach the App Store")
    }

    @Test func anythingElseIsPurchaseDidntGoThrough() {
        #expect(StoreManager.message(for: StoreKitError.unknown) == "Purchase didn't go through")
        #expect(StoreManager.message(for: CocoaError(.fileNoSuchFile)) == "Purchase didn't go through")
    }
}
