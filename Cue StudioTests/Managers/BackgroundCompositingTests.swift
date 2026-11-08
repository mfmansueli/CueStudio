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

    // MARK: - Where the creator stands

    /// The left half green screen, the right half the creator (skin).
    private var greenScreenFrame: CIImage {
        frame(left: CIColor(red: 0, green: 0.69, blue: 0.25), right: CIColor(red: 0.9, green: 0.7, blue: 0.6))
    }

    @Test func theCreatorMovesOverTheNewBackground() throws {
        var effect = BackgroundEffect()
        effect.cutout = .colorKey
        effect.style = .color
        effect.color = .white
        // The frame's middle moved a quarter to the left: the creator (the right half) now stands on the left.
        effect.person = PersonPlacement(center: OverlayPoint(x: 0.25, y: 0.5), scale: 1)
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let result = BackgroundCompositing.apply(greenScreenFrame, render: render) { _ in nil }
        #expect(result.extent == greenScreenFrame.extent)
        #expect(close(pixel(result, x: 15, y: 10), to: [230, 179, 153]), "the creator isn't on the left: \(pixel(result, x: 15, y: 10))")
        #expect(close(pixel(result, x: 35, y: 10), to: [255, 255, 255]), "where the creator stood isn't the color: \(pixel(result, x: 35, y: 10))")
    }

    @Test func theCreatorShrinksAroundTheMiddle() throws {
        var effect = BackgroundEffect()
        effect.cutout = .colorKey
        effect.style = .color
        effect.color = .white
        effect.person = PersonPlacement(center: .center, scale: 0.5)
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let result = BackgroundCompositing.apply(greenScreenFrame, render: render) { _ in nil }
        // Half the size around the middle: the creator spans 20 to 30, the corners are the color.
        #expect(close(pixel(result, x: 25, y: 10), to: [230, 179, 153]))
        #expect(close(pixel(result, x: 35, y: 10), to: [255, 255, 255]))
        #expect(close(pixel(result, x: 25, y: 1), to: [255, 255, 255]))
    }

    @Test func aBackdropGoesBehindTheCreatorWhateverTheStyle() throws {
        // An Original background: only Behind you changes the picture, with the cutout of the background.
        var effect = BackgroundEffect()
        effect.cutout = .colorKey
        let render = BackgroundRender.cutout(effect, cacheKey: "test")
        let backdrop = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 300, height: 100))
        let result = BackgroundCompositing.apply(greenScreenFrame, render: render, backdrop: backdrop) { _ in nil }
        #expect(close(pixel(result, x: 5, y: 10), to: [0, 0, 255]))
        #expect(close(pixel(result, x: 35, y: 10), to: [230, 179, 153]))
        // Without a backdrop the Original background changes nothing.
        let plain = BackgroundCompositing.apply(greenScreenFrame, render: render) { _ in nil }
        #expect(close(pixel(plain, x: 5, y: 10), to: [0, 176, 64]))
    }

    @Test func aMovedCreatorLeavesTheRoomBlurredWhereTheyStood() throws {
        var effect = BackgroundEffect()
        effect.cutout = .colorKey
        effect.style = .blur
        effect.blur = 0.5
        effect.person = PersonPlacement(center: OverlayPoint(x: 0.25, y: 0.5), scale: 1)
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let result = BackgroundCompositing.apply(greenScreenFrame, render: render) { _ in nil }
        // Where the creator stood shows the room (the green screen) spread in, not a blurred copy of them.
        let there = pixel(result, x: 35, y: 10)
        #expect(there[1] > there[0] + 60, "a ghost of the creator stays where they stood: \(there)")
    }

    @Test func aPersonMaskCutsTheCreatorOutAndMovesThem() throws {
        var effect = BackgroundEffect()
        effect.style = .color
        effect.color = .white
        effect.person = PersonPlacement(center: OverlayPoint(x: 0.75, y: 0.5), scale: 1)
        let render = try #require(BackgroundRender.prepare(effect, cacheKey: "test"))
        let image = frame(left: CIColor(red: 1, green: 0, blue: 0), right: CIColor(red: 0, green: 0, blue: 1))
        // The person is on the left; moved a quarter to the right, they stand at 10 to 30.
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 20, height: 20))
            .composited(over: CIImage(color: .black).cropped(to: image.extent))
        let result = BackgroundCompositing.apply(image, render: render) { _ in mask }
        #expect(close(pixel(result, x: 25, y: 10), to: [255, 0, 0]))
        #expect(close(pixel(result, x: 5, y: 10), to: [255, 255, 255]))
    }

    @Test func aPlacementStaysWhereTheCreatorCanBeSeen() {
        let wild = PersonPlacement(center: OverlayPoint(x: -2, y: .nan), scale: 9)
        #expect(wild.kept == PersonPlacement(center: OverlayPoint(x: 0, y: 0.5), scale: PersonPlacement.scaleRange.upperBound))
        #expect(PersonPlacement.asRecorded.isAsRecorded)
        let moved = PersonPlacement.asRecorded.moved(by: CGSize(width: 0.1, height: -0.2)).scaled(by: 0.5)
        #expect(abs(moved.center.x - 0.6) < 0.000_1 && abs(moved.center.y - 0.3) < 0.000_1 && abs(moved.scale - 0.5) < 0.000_1)
        let rect = moved.rect(in: CGSize(width: 100, height: 200))
        #expect(abs(rect.midX - 60) < 0.01 && abs(rect.midY - 60) < 0.01 && abs(rect.width - 50) < 0.01)
    }

    @Test func anOldBackgroundReadsWithTheCreatorAsRecorded() throws {
        let old = #"{"style":"color","cutout":"person","blur":0.5,"color":"black","#
            + #""key":{"red":0,"green":0.69,"blue":0.25,"tolerance":0.4,"softness":0.3,"spill":0.5}}"#
        let effect = try JSONDecoder().decode(BackgroundEffect.self, from: Data(old.utf8))
        #expect(effect.person == nil)
        #expect(!effect.movesPerson)
        // And a layout from a newer version reads as full screen.
        #expect(try JSONDecoder().decode(MediaLayout.self, from: Data(#""somewhereNew""#.utf8)) == .fullFrame)
        #expect(try JSONDecoder().decode(MediaLayout.self, from: Data(#""behind""#.utf8)) == .behind)
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
