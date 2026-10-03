//
//  ToastServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Short confirmations: one at a time, and one with a button ("Undo") stays long enough to reach it.
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
}
