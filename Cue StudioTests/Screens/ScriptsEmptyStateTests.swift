//
//  ScriptsEmptyStateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the Scripts tab shows, and the memory that tells a first use from a creator who had scripts and deleted them all.
@MainActor
@Suite("Scripts empty state")
struct ScriptsEmptyStateTests {
    @Test func loadingComesBeforeEverything() {
        #expect(ScriptsEmptyState.resolve(hasLoaded: false, scriptCount: 0, hasEverHadScript: false) == .loading)
        #expect(ScriptsEmptyState.resolve(hasLoaded: false, scriptCount: 3, hasEverHadScript: true) == .loading)
    }

    @Test func scriptsAreTheList() {
        #expect(ScriptsEmptyState.resolve(hasLoaded: true, scriptCount: 1, hasEverHadScript: false) == .list)
        #expect(ScriptsEmptyState.resolve(hasLoaded: true, scriptCount: 1, hasEverHadScript: true) == .list)
    }

    @Test func anEmptyLibraryIsTheFirstUseUntilThereWasAScript() {
        #expect(ScriptsEmptyState.resolve(hasLoaded: true, scriptCount: 0, hasEverHadScript: false) == .firstUse)
        #expect(ScriptsEmptyState.resolve(hasLoaded: true, scriptCount: 0, hasEverHadScript: true) == .returning)
        #expect(ScriptsEmptyState.firstUse.isEmpty && ScriptsEmptyState.returning.isEmpty)
        #expect(!ScriptsEmptyState.list.isEmpty && !ScriptsEmptyState.loading.isEmpty)
    }

    @Test func aNewInstallIsAFirstUse() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let history = LibraryHistory(defaults: defaults.defaults)
        history.note(scriptCount: 0)
        #expect(history.state(hasLoaded: true, scriptCount: 0) == .firstUse)
    }

    @Test func theFirstScriptMakesEveryLaterEmptyLibraryTheReturningOne() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let history = LibraryHistory(defaults: defaults.defaults)
        history.note(scriptCount: 1)
        history.note(scriptCount: 0)
        #expect(history.state(hasLoaded: true, scriptCount: 0) == .returning)
        // It is remembered: the next launch knows too.
        #expect(LibraryHistory(defaults: defaults.defaults).hasEverHadScript)
    }

    @Test func aCreatorWhoAlreadyHasScriptsCountsAsReturning() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        // An install from before the memory existed: the library loads with scripts.
        let history = LibraryHistory(defaults: defaults.defaults)
        #expect(!history.hasEverHadScript)
        history.note(scriptCount: 12)
        #expect(history.hasEverHadScript)
        #expect(history.state(hasLoaded: true, scriptCount: 0) == .returning)
    }
}
