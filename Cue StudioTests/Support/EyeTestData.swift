//
//  EyeTestData.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
@testable import Cue_Studio

/// Eyes drawn by hand for Eye Contact's tests (the face mesh needs a real face): a portrait 1080 × 1920 frame with two eyes 150 px
/// wide, open, looking where the person reads, that a test can close, turn, crowd or move.
enum EyeTestData {
    static let size = CGSize(width: 1080, height: 1920)
    static let eyeWidth = 150.0

    /// The iris's radius in eye widths (the takes measured 0.20–0.23).
    static let irisShare = 0.21

    /// One eye centered at (`x`, `y`) pixels: `opening` (lid gap over width at its middle), tilted by `roll` degrees, its iris moved
    /// by `gaze` eye widths (across, down), its outline in `EyeShape.contour`'s order for an eye on the image's `left` or right side.
    static func eye(x: Double, y: Double, onImageLeft: Bool, opening: Double = 0.3, roll: Double = 0, gaze: SIMD2<Double> = .zero) -> EyeShape {
        let half = eyeWidth / 2, lid = opening * eyeWidth / 2
        let angle = roll * .pi / 180
        func place(_ dx: Double, _ dy: Double) -> SIMD2<Double> {
            let turned = SIMD2(dx * cos(angle) - dy * sin(angle), dx * sin(angle) + dy * cos(angle))
            return SIMD2((x + turned.x) / size.width, (y + turned.y) / size.height)
        }
        let side: Double = onImageLeft ? -1 : 1
        // From the outer corner (t = 0) to the inner one (t = 1): the lids are parabolas.
        func at(_ t: Double, _ sign: Double) -> SIMD2<Double> { place(side * half * (1 - 2 * t), sign * lid * 4 * t * (1 - t)) }
        let lower = (0...8).map { at(Double($0) / 8, 1) }
        let upper = (1...7).map { at(1 - Double($0) / 8, -1) }
        return EyeShape(contour: lower + upper, iris: place(gaze.x * eyeWidth, gaze.y * eyeWidth), irisRadius: irisShare * eyeWidth / size.width)
    }

    /// A face with both eyes at the usual place (a little above the frame's middle).
    static func face(
        opening: Double = 0.3, roll: Double = 0, gaze: SIMD2<Double> = .zero, confidence: Double = 0.93, crowded: Bool = false,
        offset: CGPoint = .zero, scale: Double = 1
    ) -> EyeSample.Face {
        let centerX = 540 + Double(offset.x), centerY = 820 + Double(offset.y)
        // A tilted head turns the line between the eyes too.
        let apart = 140 * scale, angle = roll * .pi / 180
        let dx = apart * cos(angle), dy = apart * sin(angle)
        let left = eye(x: centerX - dx, y: centerY - dy, onImageLeft: true, opening: opening, roll: roll, gaze: gaze)
        let right = eye(x: centerX + dx, y: centerY + dy, onImageLeft: false, opening: opening, roll: roll, gaze: gaze)
        let box = CGRect(
            x: (centerX - 330) / size.width, y: (centerY - 300) / size.height, width: 660 / size.width, height: 800 / size.height
        )
        return EyeSample.Face(box: box, confidence: confidence, crowded: crowded, eyes: [left, right], sharpness: 40)
    }

    /// A complete analysis of `seconds` at `rate` frames a second, each frame's face from `face(time)` (nil: no face).
    static func analysis(
        seconds: Double = 10, rate: Double = 30, fileStamp: String = "test", face: (TimeInterval) -> EyeSample.Face? = { _ in EyeTestData.face() }
    ) -> EyeContactAnalysis {
        var analysis = EyeContactAnalysis(duration: seconds, width: size.width, height: size.height, fileStamp: fileStamp)
        analysis.frameRate = rate
        let frames = Int((seconds * rate).rounded())
        let samples = (0..<frames).map { index in
            let time = Double(index) / rate
            return EyeSample(time: time, face: face(time))
        }
        analysis.add(samples, over: TimeSpan(start: 0, end: seconds))
        return analysis
    }
}
