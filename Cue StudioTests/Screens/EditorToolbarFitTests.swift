//
//  EditorToolbarFitTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The toolbar's widths (`EditorToolbarFit`): tools that fit keep the class's width; tools that only just overflow (a picked
/// Blur area's four on a 6.1" iPhone: Edit · Track · Replay · Add area, then Delete pinned) narrow so all show whole, never
/// under the minimum or their label; too many keep their width and scroll.
@Suite("Toolbar widths")
struct EditorToolbarFitTests {
    /// The regular class with labels: 64 pt plus 2 pt each side, at least 54 plus 2 each side, a narrowed label keeps 6 pt
    /// around it.
    private func widths(_ labels: [CGFloat], available: CGFloat) -> [CGFloat] {
        EditorToolbarFit.widths(labels: labels, preferred: 68, minimum: 58, padding: 4, breathing: 10, available: available)
    }

    @Test func toolsThatFitKeepTheirWidth() {
        #expect(widths([34, 35, 32], available: 300) == [68, 68, 68])
        // A long label makes its tool wider, as before.
        #expect(widths([34, 70], available: 300) == [68, 74])
    }

    @Test func aPickedBlurAreasFourToolsShowWholeOnA61InchIPhone() {
        // iPhone 15 Pro, 393 pt: the back button (58) and Delete pinned (76) leave 259, less 8 of padding.
        let available: CGFloat = 393 - 58 - 76 - 8
        let labels: [CGFloat] = [34, 35, 32, 54] // Editar · Seguir · Rever · Nova área
        let fitted = widths(labels, available: available)
        #expect(abs(fitted.reduce(0, +) - available) < 0.01, "they fill the room exactly, nothing hidden under Delete")
        for (width, label) in zip(fitted, labels) {
            #expect(width >= 58 && width >= label + 10)
        }
    }

    @Test func tooManyToolsKeepTheirWidthAndScroll() {
        let labels = Array(repeating: CGFloat(40), count: 12)
        #expect(widths(labels, available: 259) == Array(repeating: 68, count: 12))
        // A scrolling bar's long labels keep the width they always had (where each tool stops after a swipe doesn't move).
        #expect(widths([70, 40, 40, 40, 40], available: 259) == [74, 68, 68, 68, 68])
    }
}
