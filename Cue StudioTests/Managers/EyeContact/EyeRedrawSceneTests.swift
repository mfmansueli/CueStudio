//
//  EyeRedrawSceneTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Eye Contact's drawing in dim light, on one eye painted on a patch: the iris's edge is drawn as soft as it was filmed, and the
/// band of iris the lower lid hid comes into view as the same columns of the iris (not rings mirrored from elsewhere).
@Suite("EyeRedrawScene")
struct EyeRedrawSceneTests {
    /// An eye 150 px wide centred at (110, 90) in a 220 × 180 patch (the lids hide the iris's top and bottom).
    private let eye = EyeTestData.eye(x: 110, y: 90, onImageLeft: true).scaled(to: EyeTestData.size)

    /// Skin, the white inside the opening, and an iris whose colour is `iris(x, distance)` inside `edgeStart`, blending to the white
    /// over `edgeWidth` pixels.
    private func painted(edgeWidth: Double, iris: (Int, Double) -> Float = { _, _ in 40 }) -> EyePatch {
        let width = 220, height = 180
        var patch = EyePatch(width: width, height: height, channels: Array(repeating: [Float](repeating: 0, count: width * height), count: 3))
        let opening = EyePatchFilters.coverage(of: eye.contour, width: width, height: height)
        let edgeStart = eye.irisRadius - edgeWidth / 2
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let r = ((Double(x) - eye.iris.x) * (Double(x) - eye.iris.x) + (Double(y) - eye.iris.y) * (Double(y) - eye.iris.y)).squareRoot()
                let toWhite = Float(min(max((r - edgeStart) / max(edgeWidth, 0.01), 0), 1))
                let ball = iris(x, r) * (1 - toWhite) + 220 * toWhite
                let inside = opening[index]
                let skin: [Float] = [150, 170, 210]
                for channel in 0..<3 { patch.channels[channel][index] = skin[channel] * (1 - inside) + ball * inside }
            }
        }
        return patch
    }

    private func classified(_ patch: EyePatch) -> EyeRedrawScene {
        var scene = EyeRedrawScene(patch: patch, eye: eye, degrees: 12)
        scene.lift()
        scene.masks()
        scene.white()
        scene.classify()
        return scene
    }

    @Test func theIrisEdgeIsAsSoftAsFilmed() {
        let soft = classified(painted(edgeWidth: 8)).edge
        #expect(soft > 6.5 && soft < 9.5, "measured \(soft) px for an 8 px edge")
        let sharp = classified(painted(edgeWidth: 0)).edge
        #expect(sharp < 3, "measured \(sharp) px for a sharp edge")
    }

    @Test func theBandTheLowerLidHidIsFilledFromTheSameColumns() throws {
        // Dark stripes 3 px wide: a column's colour tells where its pixels came from.
        let stripe: (Int) -> Float = { ($0 / 3).isMultiple(of: 2) ? 25 : 70 }
        var scene = classified(painted(edgeWidth: 2) { x, _ in stripe(x) })
        #expect(scene.rise > 10)
        scene.moveIris()
        var wrong = 0
        for x in Int(eye.iris.x) - 15...Int(eye.iris.x) + 15 {
            // A few rows below the column's last iris row as filmed (hidden by the lower lid then, in view once the iris rises): the
            // same column reflected, a third faded into the iris's colour (another column would be off by most of 45).
            let bottom = try #require(scene.irisBottom[x])
            let y = Int((bottom + 3 - scene.rise).rounded(.up))
            let filmedRow = Int((Double(y) + scene.rise).rounded())
            #expect(!scene.irisPixels[filmedRow * scene.width + x], "row \(filmedRow) was seen at column \(x)")
            if abs(scene.irisLayer.channels[0][y * scene.width + x] - stripe(x)) > 18 { wrong += 1 }
        }
        #expect(wrong == 0)
    }
}
