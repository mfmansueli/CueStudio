//
//  ToastServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Short confirmations: one at a time, each with its kind; one with a button ("Undo") stays long enough to reach it, and work
/// under way ends in the same pill as what came of it.
@MainActor
@Suite("Toasts")
struct ToastServiceTests {
    @Test func aToastWithAButtonStaysFourSecondsUnlessToldOtherwise() {
        let toast = ToastService()
        toast.defaultDuration = .seconds(2)
        #expect(toast.duration(for: nil, hasAction: false) == .seconds(2))
        #expect(toast.duration(for: nil, hasAction: true) == .seconds(4))
        #expect(toast.duration(for: .seconds(1), hasAction: true) == .seconds(1))
    }

    @Test func theButtonGoesWithItsMessage() {
        let toast = ToastService()
        var undone = 0
        toast.show("8 lines deleted", action: ToastAction(title: "Undo") { undone += 1 })
        #expect(toast.message == "8 lines deleted" && toast.action?.title == "Undo")
        toast.action?.perform()
        #expect(undone == 1)
        // A newer toast without a button never shows the old one's.
        toast.show("Saved")
        #expect(toast.message == "Saved" && toast.action == nil)
        toast.show("Line deleted", action: ToastAction(title: "Undo") {})
        toast.dismiss()
        #expect(toast.message == nil && toast.action == nil)
    }

    @Test func aToastSaysItsKindAndANewOneComesInItsOwnPill() {
        let toast = ToastService()
        toast.show("Duplicated")
        #expect(toast.kind == .done)
        let first = toast.pill
        toast.show("Move playhead onto the clip", kind: .problem)
        #expect(toast.kind == .problem && toast.pill != first)
        toast.show("Fitted to 1:00 to 1:30", kind: .cue, action: ToastAction(title: "Undo") {})
        #expect(toast.kind == .cue && toast.action != nil)
        toast.dismiss()
        #expect(toast.kind == .done && toast.message == nil)
    }

    @Test func workThatEndsTurnsItsPillIntoWhatCameOfIt() {
        let toast = ToastService()
        let work = toast.showWorking("Drafting the Reels version…")
        #expect(toast.kind == .working && toast.message == "Drafting the Reels version…" && toast.pill == work)
        // What came of it takes the ring's place: the same pill, a new icon and new words.
        toast.show("Reels version saved", kind: .cue)
        #expect(toast.pill == work && toast.kind == .cue && toast.message == "Reels version saved")
        // Ending the work afterwards leaves its result alone.
        toast.endWorking(work)
        #expect(toast.message == "Reels version saved")
        // The toast after that is a new one.
        toast.show("Duplicated")
        #expect(toast.pill != work)
    }

    @Test func workThatEndsInSilenceLetsItsRingGoButNeverAnothersToast() {
        let toast = ToastService()
        let stopped = toast.showWorking("Importing…")
        toast.endWorking(stopped)
        #expect(toast.message == nil)
        // An older piece of work ending never takes a newer one's ring, nor a toast that came after.
        let old = toast.showWorking("Freezing the frame…")
        toast.dismiss()
        let current = toast.showWorking("Extracting the sound…")
        toast.endWorking(old)
        #expect(toast.message == "Extracting the sound…" && toast.pill == current)
        toast.show("Saved to Photos")
        toast.endWorking(old)
        #expect(toast.message == "Saved to Photos")
        // A second piece of work while one runs comes in its own pill.
        let first = toast.showWorking("Freezing the frame…")
        let second = toast.showWorking("Extracting the sound…")
        #expect(first != second)
    }
}
