//
//  RestoreOutcomeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("RestoreOutcome")
struct RestoreOutcomeTests {
    /// Restore says one thing: an App Store that couldn't be asked is never "No purchases to restore".
    @Test func eachOutcomeSaysOneThing() {
        #expect(RestoreOutcome.restored.message == "Purchases restored" && RestoreOutcome.restored.isRestored)
        #expect(RestoreOutcome.nothing.message == "No purchases to restore" && !RestoreOutcome.nothing.isRestored)
        let offline = RestoreOutcome.failed(StoreManager.message(for: URLError(.notConnectedToInternet)))
        #expect(offline.message == "Can't reach the App Store" && !offline.isRestored)
    }
}
