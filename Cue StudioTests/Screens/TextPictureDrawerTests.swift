//
//  TextPictureDrawerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The picture under the fingers of a text with an effect is painted away from the main thread (`TextPictureDrawer`), one
/// at a time with only the newest request waiting, and lands so the text's picture and place agree (`TextManipulation`).
@MainActor
@Suite("Text gestures · picture drawn aside")
struct TextPictureDrawerTests {
    /// A picture whose box width names it.
    private nonisolated static func picture(_ name: CGFloat) -> TextOverlayRenderer.Drawing {
        TextOverlayRenderer.Drawing(image: UIImage(), box: CGSize(width: name, height: 10), bleed: 0)
    }

    @Test func aFastDragDrawsTheFirstAndTheNewestOnly() async {
        let drawer = TextPictureDrawer()
        var landed: [CGFloat] = []
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            drawer.draw({ Thread.sleep(forTimeInterval: 0.15); return Self.picture(1) }, then: { landed.append($0?.box.width ?? 0) })
            drawer.draw({ Self.picture(2) }, then: { landed.append($0?.box.width ?? 0) })
            drawer.draw({ Self.picture(3) }, then: {
                landed.append($0?.box.width ?? 0)
                done.resume()
            })
        }
        #expect(landed == [1, 3])
    }

    @Test(.timeLimit(.minutes(1))) func aPictureWaitingWhenTheGestureEndsNeverLands() async throws {
        let drawer = TextPictureDrawer()
        var landed: [CGFloat] = []
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            drawer.draw({ Thread.sleep(forTimeInterval: 0.1); return Self.picture(1) }, then: {
                landed.append($0?.box.width ?? 0)
                done.resume()
            })
            drawer.draw({ Self.picture(2) }, then: { landed.append($0?.box.width ?? 0) })
            drawer.cancel()
        }
        // The one waiting would be drawn right after the first: given the time, it still never lands.
        try await Task.sleep(for: .milliseconds(300))
        #expect(landed == [1])
    }

    @Test func aSideTabHoldsTheOtherSideWhereItWas() {
        var widened = TextManipulation(
            id: UUID(), grip: .trailing, center: CGPoint(x: 100, y: 100), box: CGSize(width: 100, height: 40), rotation: 0,
            shownScale: 1, opacity: 1, lineWidth: 200
        )
        widened.pixels = 1
        widened.drawing = Self.picture(160)
        // 60 points wider: the middle moves 30 to the right, so the left side stays.
        #expect(widened.sideHeldOffset == CGSize(width: 30, height: 0))
        var leading = TextManipulation(
            id: UUID(), grip: .leading, center: CGPoint(x: 100, y: 100), box: CGSize(width: 100, height: 40), rotation: .pi / 2,
            shownScale: 1, opacity: 1, lineWidth: 200
        )
        leading.drawing = Self.picture(160)
        // Turned a quarter: along the text's own line, the other way for the leading tab.
        #expect(abs(leading.sideHeldOffset.width) < 0.001)
        #expect(abs(leading.sideHeldOffset.height + 30) < 0.001)
    }

    @Test func aSharperPictureOnItsWayIsNotAskedForAgain() {
        var pinched = TextManipulation(
            id: UUID(), grip: .corner, center: .zero, box: CGSize(width: 100, height: 40), rotation: 0, shownScale: 1, opacity: 1,
            lineWidth: 200
        )
        pinched.pixels = 3
        pinched.factor = 1.5
        #expect(pinched.needsSharperPicture(displayScale: 3))
        pinched.asked = 4.5
        #expect(!pinched.needsSharperPicture(displayScale: 3))
        // Twice as big again: sharper still.
        pinched.factor = 2.2
        #expect(pinched.needsSharperPicture(displayScale: 3))
    }
}
