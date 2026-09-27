//
//  IntentRouterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("IntentRouter")
struct IntentRouterTests {
    @Test func aRequestWaitsUntilTakenOnce() {
        let router = IntentRouter()
        let id = UUID()
        router.request(.record(id))
        #expect(router.pending == .record(id))
        #expect(router.take() == .record(id))
        #expect(router.take() == nil)
    }
}
