//
//  BlurDrawingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// What Blur area draws, measured in pixels on a fine checkerboard (as busy as a face is detailed): pixels in a few large blocks
/// anchored to the area, a blur that leaves almost nothing of the pattern, an opaque bar, a soft edge that spreads outward
/// and never into the area, an oval's corners left as they were, and nothing outside touched.
@Suite("Blur area drawing")
struct BlurDrawingTests {
    private let size = CGSize(width: 400, height: 300)

    private var checkerboard: CIImage {
        CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputWidth": 4, "inputColor0": CIColor.white, "inputColor1": CIColor.black, "inputSharpness": 1,
        ])!.outputImage!.cropped(to: CGRect(origin: .zero, size: size))
    }

    /// The middle half of the picture.
    private let box = NormalizedBox(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    private func shown(_ style: BlurStyle, shape: BlurShape = .rectangle, strength: Double = 0.5, feather: Double = 0) -> BlurShown {
        var region = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 1), box: box)
        region.style = style
        region.shape = shape
        region.strength = strength
        region.feather = feather
        region.color = .red
        return BlurShown(region, at: 0)
    }

    private func spread(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(max(1, values.count))
        return (values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(max(1, values.count))).squareRoot()
    }

    @Test func pixelateIsAFewLargeBlocksAndLeavesTheRestAlone() {
        let original = RenderedPixels(checkerboard)
        let drawn = RenderedPixels(BlurDrawing.apply([shown(.pixelate, strength: 0.5)], to: checkerboard))
        // 6 blocks across the 150-pixel side: 25-pixel blocks from the area's corner (100, 75).
        let inBlock = [CGPoint(x: 103, y: 78), CGPoint(x: 112, y: 90), CGPoint(x: 122, y: 97)].map { drawn.rgb(at: $0).red }
        #expect(inBlock.max()! - inBlock.min()! < 2, "one block is one color: \(inBlock)")
        // Every block is the average of what's under it: a fine checkerboard averages to gray, nowhere near black or white.
        let inside = drawn.luma(in: CGRect(x: 102, y: 77, width: 196, height: 146))
        #expect(inside.allSatisfy { $0 > 60 && $0 < 195 }, "\(inside.min() ?? 0)…\(inside.max() ?? 0)")
        // Outside, exactly as it was.
        for point in [CGPoint(x: 20, y: 20), CGPoint(x: 390, y: 290), CGPoint(x: 95, y: 150), CGPoint(x: 305, y: 150)] {
            #expect(original.rgb(at: point) == drawn.rgb(at: point))
        }
    }

    @Test func theWeakestPixelsAreStillLarge() {
        let drawn = RenderedPixels(BlurDrawing.apply([shown(.pixelate, strength: 0)], to: checkerboard))
        // 8 blocks across 150 pixels: no block narrower than 18 pixels.
        let row = (100..<300).map { drawn.rgb(at: CGPoint(x: $0, y: 150)).red }
        var changes = 0
        for index in 1..<row.count where abs(row[index] - row[index - 1]) > 1 { changes += 1 }
        #expect(changes <= 12, "\(changes) block edges across 200 pixels")
    }

    @Test func blurLeavesAlmostNothingOfThePattern() {
        let original = RenderedPixels(checkerboard).luma(in: CGRect(x: 120, y: 95, width: 160, height: 110))
        let blurred = RenderedPixels(BlurDrawing.apply([shown(.blur, strength: 0)], to: checkerboard)).luma(in: CGRect(x: 120, y: 95, width: 160, height: 110))
        #expect(spread(blurred) < spread(original) * 0.1, "\(spread(blurred)) vs \(spread(original))")
    }

    @Test func solidIsAnOpaqueBar() {
        let drawn = RenderedPixels(BlurDrawing.apply([shown(.solid)], to: checkerboard))
        for point in [CGPoint(x: 101, y: 76), CGPoint(x: 200, y: 150), CGPoint(x: 298, y: 223)] {
            let color = drawn.rgb(at: point)
            #expect(color.red > 250 && color.green < 80 && color.blue < 80, "\(color)")
        }
    }

    @Test func aSoftEdgeSpreadsOutwardAndNeverIntoTheArea() {
        let hard = RenderedPixels(BlurDrawing.apply([shown(.solid)], to: checkerboard))
        let soft = RenderedPixels(BlurDrawing.apply([shown(.solid, feather: 1)], to: checkerboard))
        // Just inside the edge: as covered as without the soft edge.
        let inside = CGPoint(x: 101, y: 150)
        #expect(soft.rgb(at: inside) == hard.rgb(at: inside))
        // Just outside: partly red now, not before.
        let outside = CGPoint(x: 97, y: 150)
        #expect(hard.rgb(at: outside).red < 255 || hard.rgb(at: outside).green > 200)
        #expect(soft.rgb(at: outside).red > 150 && soft.rgb(at: outside).green < 200, "\(soft.rgb(at: outside))")
    }

    @Test func anOvalLeavesItsBoxsCornersAsTheyWere() {
        let original = RenderedPixels(checkerboard)
        let drawn = RenderedPixels(BlurDrawing.apply([shown(.solid, shape: .oval)], to: checkerboard))
        #expect(drawn.rgb(at: CGPoint(x: 103, y: 78)) == original.rgb(at: CGPoint(x: 103, y: 78)))
        #expect(drawn.rgb(at: CGPoint(x: 200, y: 150)).red > 250)
    }
}
