//
//  BackgroundCompositingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// Backgrounds on made-up frames: a chroma key takes the screen out (in light and in shadow) and
/// keeps skin and black, with the screen's tint taken off; the person's mask keeps them and puts
/// the color or photo behind; and the photo fills the frame.
@Suite("Background compositing")
struct BackgroundCompositingTests {
    private let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    /// A 40 × 20 frame: `left` on the left half, `right` on the right.
    private func frame(left: CIColor, right: CIColor) -> CIImage {
        let leftHalf = CIImage(color: left).cropped(to: CGRect(x: 0, y: 0, width: 20, height: 20))
        let rightHalf = CIImage(color: right).cropped(to: CGRect(x: 20, y: 0, width: 20, height: 20))
        return rightHalf.composited(over: leftHalf)
    }

    /// The color at a point, 0 to 255.
    private func pixel(_ image: CIImage, x: Int, y: Int) -> [Int] {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(
            image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return bytes.map(Int.init)
    }

    private func close(_ color: [Int], to expected: [Int], within tolerance: Int = 12) -> Bool {
        zip(color.prefix(3), expected).allSatisfy { abs($0 - $1) <= tolerance }
    }

    // MARK: - Chroma key math

    @Test func theScreenGoesInLightAndInShadow() {
        let key = ChromaKey.green
        #expect(ChromaKeyCube.alpha(red: key.red, green: key.green, blue: key.blue, key: key) == 0)
        #expect(ChromaKeyCube.alpha(red: 0, green: 0.35, blue: 0.13, key: key) == 0)
    }

    @Test func skinWhiteAndBlackStay() {
        let key = ChromaKey.green
        #expect(ChromaKeyCube.alpha(red: 0.9, green: 0.7, blue: 0.6, key: key) == 1)
        #expect(ChromaKeyCube.alpha(red: 1, green: 1, blue: 1, key: key) == 1)
        #expect(ChromaKeyCube.alpha(red: 0.02, green: 0.03, blue: 0.02, key: key) > 0.7)
    }

    @Test func spillTakesTheScreensTintOff() {
        var key = ChromaKey.green
        key.spill = 1
        let kept = ChromaKeyCube.despilled(red: 0.6, green: 0.8, blue: 0.5, key: key)
        #expect(abs(kept.green - 0.6) < 0.001)
        key.spill = 0
        #expect(ChromaKeyCube.despilled(red: 0.6, green: 0.8, blue: 0.5, key: key).green == 0.8)
    }

    @Test func aWiderToleranceTakesMoreOut() {
        var key = ChromaKey.green
        let lightGreen = (red: 0.45, green: 0.8, blue: 0.45)
        key.tolerance = 0.2
        let narrow = ChromaKeyCube.alpha(red: lightGreen.red, green: lightGreen.green, blue: lightGreen.blue, key: key)
        key.tolerance = 0.9
        let wide = ChromaKeyCube.alpha(red: lightGreen.red, green: lightGreen.green, blue: lightGreen.blue, key: key)
        #expect(wide < narrow)
    }

    @Test func theCubeHasEveryEntry() {
        let size = ChromaKeyCube.size
        #expect(ChromaKeyCube.data(for: .blue).count == size * size * size * 4 * MemoryLayout<Float>.size)
    }

    // MARK: - Compositing

    @Test func aColorKeyPutsTheColorWhereTheScreenWas() throws {
        var effect = BackgroundEffect()
        effect.cutout = .colorKey
        effect.style = .color
        effect.color = .blue
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let image = frame(left: CIColor(red: 0, green: 0.69, blue: 0.25), right: CIColor(red: 0.9, green: 0.7, blue: 0.6))
        let result = BackgroundCompositing.apply(image, render: render) { _ in nil }
        #expect(result.extent == image.extent)
        let blue = OverlayColor.blue.components
        #expect(close(pixel(result, x: 5, y: 10), to: [Int(blue.red * 255), Int(blue.green * 255), Int(blue.blue * 255)]))
        #expect(close(pixel(result, x: 35, y: 10), to: [230, 179, 153]))
    }

    @Test func thePersonStaysInFrontOfTheColor() throws {
        var effect = BackgroundEffect()
        effect.style = .color
        effect.color = .white
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let image = frame(left: CIColor(red: 1, green: 0, blue: 0), right: CIColor(red: 0, green: 0, blue: 1))
        // The person is on the left.
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 20, height: 20))
            .composited(over: CIImage(color: .black).cropped(to: image.extent))
        let result = BackgroundCompositing.apply(image, render: render) { _ in mask }
        #expect(close(pixel(result, x: 5, y: 10), to: [255, 0, 0]))
        #expect(close(pixel(result, x: 35, y: 10), to: [255, 255, 255]))
    }

    @Test func withoutAMaskTheFrameStaysAsItIs() throws {
        var effect = BackgroundEffect()
        effect.style = .blur
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let image = frame(left: CIColor(red: 1, green: 0, blue: 0), right: CIColor(red: 0, green: 0, blue: 1))
        let result = BackgroundCompositing.apply(image, render: render) { _ in nil }
        #expect(close(pixel(result, x: 35, y: 10), to: [0, 0, 255]))
    }

    @Test func aBlurKeepsTheFrameSize() throws {
        var effect = BackgroundEffect()
        effect.style = .blur
        effect.blur = 1
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let image = frame(left: CIColor(red: 1, green: 0, blue: 0), right: CIColor(red: 0, green: 0, blue: 1))
        let blurred = try #require(BackgroundCompositing.background(for: image, render: render))
        #expect(blurred.extent == image.extent)
        // The two halves run into each other at the middle.
        let middle = pixel(blurred, x: 20, y: 10)
        #expect(middle[0] > 40 && middle[2] > 40)
    }

    @Test func anImageWithoutItsPhotoChangesNothing() {
        var effect = BackgroundEffect()
        effect.style = .image
        #expect(!effect.isActive)
        effect.imageFileName = "gone-\(UUID().uuidString).jpg"
        #expect(effect.isActive)
        // The photo was deleted: nothing to put behind.
        #expect(BackgroundRender.prepare(effect, cacheKey: "test") == nil)
    }
}
