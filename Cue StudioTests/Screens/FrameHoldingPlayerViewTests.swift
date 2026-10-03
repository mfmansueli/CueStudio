//
//  FrameHoldingPlayerViewTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
import UIKit
@testable import Cue_Studio

/// The picture held over the preview covers the swap to a new item and never outstays it.
@MainActor
@Suite("FrameHoldingPlayerView")
struct FrameHoldingPlayerViewTests {
    private func picture() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 9, height: 16, bitsPerComponent: 8, bytesPerRow: 36,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 9, height: 16))
        return try #require(context.makeImage())
    }

    @Test func aHeldPictureShowsUntilItIsLetGo() async throws {
        let view = FrameHoldingPlayerView(frame: CGRect(x: 0, y: 0, width: 90, height: 160))
        #expect(!view.isHoldingFrame)
        view.hold(try picture())
        #expect(view.isHoldingFrame)
        try await Task.sleep(for: .milliseconds(300))
        #expect(view.isHoldingFrame)
        // No new item ever shows a picture here: the hold doesn't outstay its limit (1 s).
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while view.isHoldingFrame, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!view.isHoldingFrame)
    }
}
