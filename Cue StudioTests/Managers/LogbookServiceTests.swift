//
//  LogbookServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Logbook: ideas caught now, shaped later.
@MainActor
@Suite("LogbookService")
struct LogbookServiceTests {
    private func make() -> (LogbookService, TestDefaults) {
        let defaults = TestDefaults()
        return (LogbookService(defaults: defaults.defaults, now: { TestData.now }), defaults)
    }

    @Test func anIdeaIsKeptNewestFirstAndBlankOnesAreNot() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        #expect(logbook.add("   ") == nil)
        logbook.add("First idea")
        logbook.add("Second idea", spokenSeconds: 14)
        #expect(logbook.entries.map(\.text) == ["Second idea", "First idea"])
        #expect(logbook.entries[0].isSpoken && !logbook.entries[1].isSpoken)
    }

    @Test func aShapedIdeaNoLongerWaits() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let entry = logbook.add("Cold showers: myth vs. what helped")
        let id = entry?.id ?? UUID()
        #expect(logbook.waiting.count == 1)
        logbook.markShaped(id, as: UUID())
        #expect(logbook.waiting.isEmpty && logbook.entries.count == 1)
    }

    @Test func theIdeasSurviveARelaunch() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let entry = logbook.add("Why I stopped buying coffee out", spokenSeconds: 14)
        logbook.setTopic("niche.finance", of: entry?.id ?? UUID())
        let again = LogbookService(defaults: defaults.defaults)
        #expect(again.entries.count == 1)
        #expect(again.entries[0].topic == "niche.finance" && again.entries[0].spokenSeconds == 14)
    }

    /// A corrected idea keeps its place, its day and how it came in; blank words change nothing.
    @Test func anIdeaIsCorrectedInPlace() throws {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let spoken = try #require(logbook.add("Slow mornigns", spokenSeconds: 6))
        logbook.add("Desk lamps")
        let edited = try #require(logbook.edit(spoken.id, text: "  Slow mornings "))
        #expect(edited.text == "Slow mornings" && edited.spokenSeconds == 6 && edited.createdAt == spoken.createdAt)
        #expect(logbook.entries.map(\.text) == ["Desk lamps", "Slow mornings"])
        #expect(logbook.edit(spoken.id, text: "   ") == nil)
        #expect(LogbookService(defaults: defaults.defaults).entries.last?.text == "Slow mornings")
    }

    /// The words left in the field come back the next time, across a relaunch; blank ones and "Delete my Cue data" leave nothing.
    @Test func theFieldsWordsWaitForTheNextVisit() {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        logbook.keepDraft("Half an idea about")
        #expect(LogbookService(defaults: defaults.defaults).draft == "Half an idea about")
        logbook.keepDraft("   ")
        #expect(logbook.draft.isEmpty && LogbookService(defaults: defaults.defaults).draft.isEmpty)
        logbook.keepDraft("Another")
        logbook.eraseAll()
        #expect(LogbookService(defaults: defaults.defaults).draft.isEmpty)
    }

    /// A deleted idea is gone for good, across a relaunch too; "Delete my Cue data" takes every idea.
    @Test func deletingRemovesItForGood() throws {
        let (logbook, defaults) = make()
        defer { defaults.tearDown() }
        let id = try #require(logbook.add("Gone soon")).id
        let kept = try #require(logbook.add("Kept")).id
        logbook.delete([id])
        #expect(logbook.entries.map(\.id) == [kept])
        #expect(LogbookService(defaults: defaults.defaults).entries.map(\.id) == [kept], "Gone on the iPhone too")
        logbook.eraseAll()
        #expect(logbook.entries.isEmpty)
    }

    /// Several go at once and come back with an Undo, each where it was among the others (newest first).
    @Test func deletingSeveralCanBeUndoneInPlace() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        var clock = TestData.now
        let logbook = LogbookService(defaults: defaults.defaults, now: { clock })
        let first = try #require(logbook.add("First"))
        clock = clock.addingTimeInterval(60)
        let second = try #require(logbook.add("Second"))
        clock = clock.addingTimeInterval(60)
        logbook.add("Third")
        let removed = logbook.delete([first.id, second.id])
        #expect(Set(removed.map(\.id)) == [first.id, second.id])
        #expect(logbook.entries.map(\.text) == ["Third"])
        logbook.restore(removed)
        #expect(logbook.entries.map(\.text) == ["Third", "Second", "First"])
        logbook.restore(removed)
        #expect(logbook.entries.count == 3, "Restoring twice keeps one of each")
        #expect(LogbookService(defaults: defaults.defaults).entries.count == 3, "Kept on the iPhone")
    }
}
