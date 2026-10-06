//
//  SkinFaceFixture.swift
//  Cue StudioTests
//

import CoreGraphics
import CoreImage
import Foundation
@testable import Cue_Studio

/// A drawn face and the landmarks that describe it, for the tests of Skin Smoothing: skin with fine texture and small blemishes, a crease (an edge
/// that must stay), eyes, brows, lips, dark hair around the face and, on the chin, stubble. Coordinates are in pixels, y up from the bottom.
enum SkinFaceFixture {
    static let size = CGSize(width: 480, height: 640)

    /// Where things are, in pixels.
    static let center = CGPoint(x: 240, y: 320)
    static let radii = CGSize(width: 150, height: 200)
    static let eyeCenters = [CGPoint(x: 185, y: 375), CGPoint(x: 295, y: 375)]
    static let browLines = [(CGPoint(x: 145, y: 415), CGPoint(x: 225, y: 420)), (CGPoint(x: 255, y: 420), CGPoint(x: 335, y: 415))]
    static let lipsCenter = CGPoint(x: 240, y: 215)
    /// A patch of cheek with nothing on it but skin, a crease across the other cheek, and the stubble on the chin.
    static let cheek = CGRect(x: 120, y: 270, width: 70, height: 70)
    static let crease = CGRect(x: 292, y: 262, width: 50, height: 6)
    static let stubble = CGRect(x: 205, y: 140, width: 70, height: 40)
    static let skinColor = (red: 0.84, green: 0.63, blue: 0.53)
    static let hairColor = (red: 0.16, green: 0.12, blue: 0.11)

    // MARK: - Landmarks

    /// The landmarks of the drawn face, in the unit square of a frame of `frame` (the fixture's own size unless it sits in a bigger one).
    static func landmarks(shiftedBy shift: CGPoint = .zero, in frame: CGSize = size) -> FaceLandmarks {
        func unit(_ point: CGPoint) -> CGPoint { CGPoint(x: (point.x + shift.x) / frame.width, y: (point.y + shift.y) / frame.height) }
        func ellipse(_ middle: CGPoint, _ rx: CGFloat, _ ry: CGFloat, count: Int) -> [CGPoint] {
            (0..<count).map { index in
                let angle = Double(index) / Double(count) * 2 * .pi
                return unit(CGPoint(x: middle.x + rx * cos(angle), y: middle.y + ry * sin(angle)))
            }
        }
        // The jaw runs from just under one ear, round the chin, to the other.
        let jaw = (0..<17).map { index -> CGPoint in
            let angle = (190 + Double(index) / 16 * 160) * .pi / 180
            return unit(CGPoint(x: center.x + radii.width * cos(angle), y: center.y + radii.height * sin(angle)))
        }
        let brows = browLines.map { line in
            (0..<5).map { index in
                let amount = CGFloat(index) / 4
                return unit(CGPoint(x: line.0.x + (line.1.x - line.0.x) * amount, y: line.0.y + (line.1.y - line.0.y) * amount))
            }
        }
        let box = CGRect(
            x: (center.x - radii.width + shift.x) / frame.width, y: (center.y - radii.height + shift.y) / frame.height,
            width: radii.width * 2 / frame.width, height: (radii.height + 90) / frame.height
        )
        return FaceLandmarks(
            box: box, contour: jaw, leftEye: ellipse(eyeCenters[0], 24, 11, count: 6), rightEye: ellipse(eyeCenters[1], 24, 11, count: 6),
            leftBrow: brows[0], rightBrow: brows[1], outerLips: ellipse(lipsCenter, 46, 15, count: 12), innerLips: ellipse(lipsCenter, 30, 4, count: 6)
        )
    }

    // MARK: - Picture

    /// The frame: hair, then the face with its texture, blemishes, crease, eyes, brows, lips and stubble. Deterministic.
    static func image(shiftedBy shift: CGPoint = .zero, texture: Double = 1, skin: Double = 1) -> CIImage {
        var pixels = [UInt8](repeating: 0, count: Int(size.width) * Int(size.height) * 4)
        let width = Int(size.width), height = Int(size.height)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func random() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed % 10_000) / 10_000
        }
        let blemishes = (0..<60).map { _ in CGPoint(x: 100 + random() * 280 - shift.x, y: 160 + random() * 300 - shift.y) }
        for row in 0..<height {
            for column in 0..<width {
                // Row 0 is the top of the picture; the geometry is y up.
                let point = CGPoint(x: Double(column) - shift.x, y: Double(height - 1 - row) - shift.y)
                var color = color(at: point, texture: texture, skin: skin, blemishes: blemishes, noise: random() - 0.5)
                color = clampColor(color)
                let index = (row * width + column) * 4
                pixels[index] = UInt8(color.red * 255)
                pixels[index + 1] = UInt8(color.green * 255)
                pixels[index + 2] = UInt8(color.blue * 255)
                pixels[index + 3] = 255
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)
        let space = CGColorSpace(name: CGColorSpace.sRGB)
        guard let provider, let space, let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return CIImage.empty() }
        return CIImage(cgImage: image)
    }

    private typealias RGB = (red: Double, green: Double, blue: Double)

    private static func color(at point: CGPoint, texture: Double, skin: Double, blemishes: [CGPoint], noise: Double) -> RGB {
        let dx = (point.x - center.x) / radii.width, dy = (point.y - center.y) / radii.height
        // Dark hair around and above the face.
        let inFace = dx * dx + dy * dy <= 1
        let inHair = (point.x - center.x) * (point.x - center.x) / (190 * 190) + (point.y - center.y) * (point.y - center.y) / (250 * 250) <= 1
        guard inFace else { return inHair || point.y > center.y ? hairColor : (red: 0.2, green: 0.25, blue: 0.3) }
        // Skin: a slow shade across the face, fine grain, and small dark blemishes.
        var color = (
            red: skinColor.red * skin - 0.05 * dy * skin + noise * 0.05 * texture,
            green: skinColor.green * skin - 0.05 * dy * skin + noise * 0.05 * texture,
            blue: skinColor.blue * skin - 0.04 * dy * skin + noise * 0.045 * texture
        )
        for spot in blemishes {
            let distance = hypot(point.x - spot.x, point.y - spot.y)
            if distance < 3.2 {
                let depth = 0.10 * texture * (1 - distance / 3.2)
                color = (color.red - depth, color.green - depth * 1.3, color.blue - depth * 1.2)
            }
        }
        // The crease: an edge far stronger than any texture.
        if crease.contains(point) { color = (color.red - 0.30, color.green - 0.30, color.blue - 0.28) }
        // Stubble: dark specks closer than the skin between them.
        if stubble.contains(point), (Int(point.x) * 7 + Int(point.y) * 13) % 5 == 0 { color = (0.30, 0.22, 0.19) }
        return features(at: point) ?? color
    }

    /// Eyes (white, with a dark iris), brows and lips drawn over the skin; nil where there are none.
    private static func features(at point: CGPoint) -> RGB? {
        for eye in eyeCenters {
            let ex = (point.x - eye.x) / 24, ey = (point.y - eye.y) / 11
            if ex * ex + ey * ey <= 1 { return hypot(point.x - eye.x, (point.y - eye.y) * 1.6) < 7 ? (0.15, 0.09, 0.07) : (0.93, 0.93, 0.93) }
            if ex * ex + ey * ey <= 1.6 { return (0.20, 0.13, 0.11) }
        }
        for line in browLines {
            let along = (point.x - line.0.x) / (line.1.x - line.0.x)
            let onLine = line.0.y + (line.1.y - line.0.y) * along
            if along >= 0, along <= 1, abs(point.y - onLine) <= 5 { return (0.22, 0.14, 0.10) }
        }
        let lx = (point.x - lipsCenter.x) / 46, ly = (point.y - lipsCenter.y) / 15
        return lx * lx + ly * ly <= 1 ? (0.75, 0.33, 0.38) : nil
    }

    private static func clampColor(_ color: RGB) -> RGB {
        (min(max(color.red, 0), 1), min(max(color.green, 0), 1), min(max(color.blue, 0), 1))
    }
}
