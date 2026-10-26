//
//  HandleSpreadTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// Handles around a shape on the preview (`HandleSpread`): where there's room they stay where they mean; on a small mask or a
/// small Blur area they move out until every one is a finger apart from the others and from the middle; a single tab with no
/// room on its side goes to the other side; and they stay on the preview, never onto another.
@Suite("Handles a finger apart")
struct HandleSpreadTests {
    private let preview = CGRect(x: 0, y: 0, width: 360, height: 640)
    private let spacing: CGFloat = 44

    /// A mask's handles as `MaskEditingLayer` asks for them: right and bottom tabs, ↻ above, the soft-edge arrow below, the
    /// corner dot inside the top left corner.
    private func maskHandles(center: CGPoint, halfWidth: CGFloat, halfHeight: CGFloat) -> [HandleSpread.Handle] {
        [
            HandleSpread.Handle("right", at: CGPoint(x: center.x + halfWidth, y: center.y), outward: CGVector(dx: 1, dy: 0)),
            HandleSpread.Handle("bottom", at: CGPoint(x: center.x, y: center.y + halfHeight), outward: CGVector(dx: 0, dy: 1)),
            HandleSpread.Handle("turn", at: CGPoint(x: center.x, y: center.y - halfHeight - 26), outward: CGVector(dx: 0, dy: -1)),
            HandleSpread.Handle("feather", at: CGPoint(x: center.x, y: center.y + halfHeight + 26), outward: CGVector(dx: 0, dy: 1)),
            HandleSpread.Handle(
                "corners", at: CGPoint(x: center.x - halfWidth + 12, y: center.y - halfHeight + 12), outward: CGVector(dx: -1, dy: -1)
            ),
        ]
    }

    private func closest(_ places: [String: CGPoint], center: CGPoint) -> CGFloat {
        let points = Array(places.values) + [center]
        var nearest = CGFloat.infinity
        for (index, point) in points.enumerated() {
            for other in points[(index + 1)...] { nearest = min(nearest, HandleSpread.distance(point, other)) }
        }
        return nearest
    }

    @Test func aLargeShapeKeepsItsHandlesWhereTheyMean() {
        let center = CGPoint(x: 180, y: 320)
        let handles = maskHandles(center: center, halfWidth: 120, halfHeight: 90)
        let places = HandleSpread.place(handles, around: center, in: preview, spacing: spacing, margin: 12).mapValues(\.point)
        // The tabs and the corner dot stay on the outline; ↻ and the arrow move out only to clear the tabs beside them.
        #expect(places["right"] == handles[0].anchor)
        #expect(places["bottom"] == handles[1].anchor)
        #expect(places["corners"] == handles[4].anchor)
        #expect(closest(places, center: center) >= spacing - 0.5)
    }

    @Test func aSmallMaskSpreadsItsHandlesAFingerApart() {
        let center = CGPoint(x: 180, y: 320)
        for half in [CGFloat(4), 12, 20, 30] {
            let handles = maskHandles(center: center, halfWidth: half, halfHeight: half * 0.8)
            let places = HandleSpread.place(handles, around: center, in: preview, spacing: spacing, margin: 12).mapValues(\.point)
            #expect(places.count == 5)
            #expect(closest(places, center: center) >= spacing - 0.5, "handles crowd each other on a mask \(half * 2) pt wide")
            // Each moved only outwards, away from the middle, along its own way.
            #expect((places["right"]?.x ?? 0) > center.x && abs((places["right"]?.y ?? 0) - center.y) < 0.5)
            #expect((places["turn"]?.y ?? 0) < center.y && (places["feather"]?.y ?? 0) > (places["bottom"]?.y ?? 0))
        }
    }

    @Test func handlesStayOnThePreviewWithoutPilingUp() {
        // A small mask in the top left corner: the ones pushed off the preview come back along its edge, apart.
        let center = CGPoint(x: 20, y: 20)
        let handles = maskHandles(center: center, halfWidth: 10, halfHeight: 10)
        let places = HandleSpread.place(handles, around: center, in: preview, spacing: spacing, margin: 12).mapValues(\.point)
        for point in places.values {
            #expect(point.x >= 11.9 && point.x <= preview.maxX - 11.9 && point.y >= 11.9 && point.y <= preview.maxY - 11.9)
        }
        let points = Array(places.values)
        for (index, point) in points.enumerated() {
            for other in points[(index + 1)...] { #expect(HandleSpread.distance(point, other) >= spacing - 0.5) }
        }
    }

    @Test func aSmallBlurAreaLeavesItsMiddleToDrag() {
        // An area over an eye, 40 × 16 pt: ✕ and the three corners spread along their diagonals, the middle free.
        let rect = CGRect(x: 160, y: 300, width: 40, height: 16)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let corners = [(CGFloat(-1), CGFloat(-1)), (1, -1), (-1, 1), (1, 1)].enumerated().map { index, way in
            HandleSpread.Handle(
                "\(index)", at: CGPoint(x: center.x + way.0 * 20, y: center.y + way.1 * 8), outward: CGVector(dx: way.0, dy: way.1)
            )
        }
        let places = HandleSpread.place(corners, around: center, in: preview, spacing: spacing, margin: 12).mapValues(\.point)
        #expect(closest(places, center: center) >= spacing - 0.5)
    }

    @Test func aSingleTabWithNoRoomOnItsSideGoesToTheOther() {
        // A small mask 40 pt from the right edge of a narrow preview (the panel open): its width tab can't sit on the right.
        let narrow = CGRect(x: 0, y: 0, width: 160, height: 288)
        let center = CGPoint(x: 120, y: 140)
        let tab = HandleSpread.Handle(
            "right", at: CGPoint(x: 124, y: 140), outward: CGVector(dx: 1, dy: 0),
            otherSide: (anchor: CGPoint(x: 116, y: 140), outward: CGVector(dx: -1, dy: 0))
        )
        let spot = HandleSpread.place([tab], around: center, in: narrow, spacing: spacing, margin: 12)["right"]
        #expect(spot?.point == CGPoint(x: 76, y: 140), "level with the mask, on its left")
        #expect(spot?.anchor == CGPoint(x: 116, y: 140), "and it belongs to the left side")
    }
}
