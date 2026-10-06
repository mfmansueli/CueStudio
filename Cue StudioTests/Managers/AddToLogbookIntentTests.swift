//
//  AddToLogbookIntentTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Add an idea to Cue" (Siri, Shortcuts): the idea waits in the Logbook as a typed one would.
@MainActor
@Suite("AddToLogbookIntent")
struct AddToLogbookIntentTests {
    @Test func anIdeaFromSiriWaitsInTheLogbook() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let logbook = LogbookService(defaults: defaults.defaults, now: { TestData.now })
        #expect(AddToLogbookIntent.save("  A video about slow mornings ", in: logbook))
        #expect(logbook.waiting.map(\.text) == ["A video about slow mornings"])
        #expect(logbook.waiting.first?.isSpoken == false)
        // Kept on this iPhone: the app finds it the next time it opens.
        #expect(LogbookService(defaults: defaults.defaults).waiting.count == 1)
    }

    @Test func blankWordsSaveNothing() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let logbook = LogbookService(defaults: defaults.defaults)
        #expect(!AddToLogbookIntent.save("   ", in: logbook))
        #expect(logbook.entries.isEmpty)
    }
}
