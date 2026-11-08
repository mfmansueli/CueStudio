//
//  ScreenAwakeTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// One auto-lock flag, many owners: the screen locks again only when the last one lets go.
@MainActor
@Suite("Screen awake")
struct ScreenAwakeTests {
    private final class Flag {
        var applied: [Bool] = []
    }

    @Test func theLastOwnerToLetGoGivesAutoLockBack() {
        let flag = Flag()
        let screen = ScreenAwake { flag.applied.append($0) }
        screen.hold("prompter")
        screen.hold("export-1")
        screen.release("prompter")
        #expect(screen.isHeld)
        #expect(flag.applied == [true])
        screen.release("export-1")
        #expect(!screen.isHeld)
        #expect(flag.applied == [true, false])
    }

    @Test func holdingTwiceUnderOneNameIsHoldingOnce() {
        let flag = Flag()
        let screen = ScreenAwake { flag.applied.append($0) }
        screen.hold("remote")
        screen.hold("remote")
        screen.release("remote")
        #expect(!screen.isHeld)
        #expect(flag.applied == [true, false])
    }

    @Test func lettingGoOfWhatIsntHeldChangesNothing() {
        let flag = Flag()
        let screen = ScreenAwake { flag.applied.append($0) }
        screen.release("export-1")
        screen.hold("prompter")
        screen.release("export-1")
        #expect(screen.isHeld)
        #expect(flag.applied == [true])
    }
}
