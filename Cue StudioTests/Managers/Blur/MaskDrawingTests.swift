//
//  MaskDrawingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// What a mask leaves of a red picture filling its place (drawn over black, so what's cut out is black): only the inside of a
/// rectangle, a circle, the side above a line, a band; the outside when inverted; turned where it's turned; and a soft edge
/// fading across the shape's line.
@Suite("Mask drawing")
struct MaskDrawingTests {
    private let place = CGRect(x: 0, y: 0, width: 400, height: 400)

    private func drawn(_ shape: MaskShape, _ placement: MaskPlacement, inverted: Bool = false) -> RenderedPixels {
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: place)
        let masked = MaskDrawing.apply(MediaMask(shape: shape, placement: placement, inverted: inverted), placement: placement, to: red, in: place)
        return RenderedPixels(masked.composited(over: CIImage(color: .black).cropped(to: place)))
    }

    /// Red there, from the top left.
    private func shows(_ pixels: RenderedPixels, _ x: CGFloat, _ yFromTop: CGFloat) -> Bool {
        pixels.rgb(at: CGPoint(x: x, y: place.height - yFromTop)).red > 200
    }

    @Test func aRectangleShowsOnlyItsInside() {
        let pixels = drawn(.rectangle, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.25), width: 0.5, height: 0.2))
        #expect(shows(pixels, 200, 100))
        #expect(!shows(pixels, 200, 300))
        #expect(!shows(pixels, 60, 100))
    }

    @Test func invertedItShowsTheOutside() {
        let pixels = drawn(.rectangle, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.25), width: 0.5, height: 0.2), inverted: true)
        #expect(!shows(pixels, 200, 100))
        #expect(shows(pixels, 200, 300))
    }

    @Test func roundedCornersCutTheCorners() {
        let square = drawn(.rectangle, MaskPlacement(width: 0.5, height: 0.5))
        let rounded = drawn(.rectangle, MaskPlacement(width: 0.5, height: 0.5, corners: 1))
        #expect(shows(square, 103, 103))
        #expect(!shows(rounded, 103, 103))
        #expect(shows(rounded, 200, 200))
    }

    @Test func aCircleIsRound() {
        let pixels = drawn(.circle, MaskPlacement(width: 0.5, height: 0.5))
        #expect(shows(pixels, 200, 200))
        #expect(shows(pixels, 200, 110))
        #expect(!shows(pixels, 112, 112), "a box's corner is outside the circle")
    }

    @Test func aLineShowsTheSideAboveItAndTurnsWithIt() {
        let flat = drawn(.line, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.5)))
        #expect(shows(flat, 200, 100))
        #expect(!shows(flat, 200, 300))
        // Turned a quarter clockwise, what was above is on the right.
        let turned = drawn(.line, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.5), rotation: 90))
        #expect(shows(turned, 300, 200))
        #expect(!shows(turned, 100, 200))
    }

    @Test func aBandShowsItsStrip() {
        let pixels = drawn(.band, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.5), height: 0.2))
        #expect(shows(pixels, 200, 200))
        #expect(!shows(pixels, 200, 100))
        #expect(!shows(pixels, 200, 300))
    }

    @Test func aSoftEdgeFadesAcrossTheLine() {
        let hard = drawn(.line, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.5)))
        let soft = drawn(.line, MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.5), feather: 1))
        // 20 pixels below the line: cut out sharply, half faded softly.
        let below = soft.rgb(at: CGPoint(x: 200, y: 180)).red
        #expect(hard.rgb(at: CGPoint(x: 200, y: 180)).red < 10)
        #expect(below > 20 && below < 200, "\(below)")
    }
}
