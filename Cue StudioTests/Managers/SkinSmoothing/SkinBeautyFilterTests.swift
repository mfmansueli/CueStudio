//
//  SkinBeautyFilterTests.swift
//  Cue StudioTests
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Testing
@testable import Cue_Studio

/// Today's Skin engine on a drawn face rendered by the software renderer: the smoothing is stronger than the first engine's at its top, grows with
/// the dial, keeps its texture apart and never brightens; the face light and the anti-shine work on the face alone; and every feature, the hair
/// and the background stay as they were.
@Suite("Skin filters (today's engine)", .serialized, .timeLimit(.minutes(5)))
struct SkinBeautyFilterTests {
    private static let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])

    /// The drawn face (with a shine on its cheek, when asked), found by a fake detector, drawn with each look.
    private struct Rendered {
        let image: CIImage
        let pass: SkinSmoothingPass
        let original: RenderedPixels

        init(shine: Bool = false) {
            var image = SkinFaceFixture.image()
            if shine { image = SkinBeautyFilterTests.shining(image) }
            self.image = image
            let smoother = SkinSmoother(context: SkinBeautyFilterTests.context, detector: FakeFaceDetector(faces: [SkinFaceFixture.landmarks()]))
            pass = smoother.pass(for: image, stream: .main, epoch: 0, time: 0)
            original = RenderedPixels(image)
        }

        func drawn(_ look: SkinLook) -> RenderedPixels { RenderedPixels(pass.apply(look, to: image)) }
    }

    private static let plain = Rendered()
    private static let shiny = Rendered(shine: true)
    private static let todaysTop = plain.drawn(.smoothing(100))

    private let cheek = SkinFaceFixture.cheek
    private let wholeFrame = CGRect(origin: .zero, size: SkinFaceFixture.size)

    /// A white shine on the cheek, like a highlight on oily skin: the light's own colour over the skin, brightest at its middle.
    private static let shineCenter = CGPoint(x: 155, y: 305)

    private static func shining(_ image: CIImage) -> CIImage {
        let gradient = CIFilter.radialGradient()
        gradient.center = shineCenter
        gradient.radius0 = 0
        gradient.radius1 = 14
        gradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 0.8)
        gradient.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        guard let shine = gradient.outputImage else { return image }
        return shine.cropped(to: image.extent).composited(over: image)
    }

    private func luma(_ pixels: RenderedPixels, in rect: CGRect) -> Double {
        let values = pixels.luma(in: rect)
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Smoothing

    @Test func todaysTopSmoothsMoreThanTheFirstEnginesTop() {
        let first = Self.plain.drawn(.firstEngine(100)).texture(in: cheek)
        let today = Self.todaysTop.texture(in: cheek)
        #expect(today < first * 0.9, "the first engine's 100 leaves \(first), today's \(today)")
    }

    @Test func aHigherAmountSmoothsMore() {
        let original = Self.plain.original.texture(in: cheek)
        let weak = Self.plain.drawn(.smoothing(25)).texture(in: cheek)
        let middle = Self.plain.drawn(.smoothing(50)).texture(in: cheek)
        let strong = Self.todaysTop.texture(in: cheek)
        #expect(original > weak && weak > middle && middle > strong, "\(original) → \(weak) → \(middle) → \(strong)")
    }

    @Test func theTextureLaysTheGrainBackWithoutSharpening() {
        let none = Self.plain.drawn(.smoothing(100, texture: 0)).texture(in: cheek)
        let some = Self.todaysTop.texture(in: cheek)
        let all = Self.plain.drawn(.smoothing(100, texture: 100)).texture(in: cheek)
        #expect(none < some && some < all, "\(none) → \(some) → \(all)")
        #expect(all <= Self.plain.original.texture(in: cheek) + 0.05, "texture brings back the skin's own grain, never more than it had")
    }

    @Test func theSmoothingNeverBrightensTheSkinNorShiftsItsColour() {
        for rect in [cheek, CGRect(x: 200, y: 300, width: 80, height: 60), CGRect(x: 205, y: 430, width: 70, height: 40)] {
            let before = Self.plain.original.mean(in: rect), after = Self.todaysTop.mean(in: rect)
            #expect(luma(Self.todaysTop, in: rect) - luma(Self.plain.original, in: rect) < 1, "\(rect) got brighter")
            let shift = max(abs(after.red - before.red), abs(after.green - before.green), abs(after.blue - before.blue))
            #expect(shift < 2.5, "\(rect): \(before) → \(after)")
        }
    }

    @Test func theSmoothingLeavesTheFeaturesTheHairAndTheBackgroundAlone() {
        let strong = Self.todaysTop
        for eye in SkinFaceFixture.eyeCenters {
            #expect(strong.greatestDifference(from: Self.plain.original, in: CGRect(x: eye.x - 14, y: eye.y - 5, width: 28, height: 10)) <= 3)
        }
        for line in SkinFaceFixture.browLines {
            let rect = CGRect(x: (line.0.x + line.1.x) / 2 - 15, y: (line.0.y + line.1.y) / 2 - 3, width: 30, height: 6)
            #expect(strong.greatestDifference(from: Self.plain.original, in: rect) <= 3, "a brow changed")
        }
        let lips = CGRect(x: SkinFaceFixture.lipsCenter.x - 28, y: SkinFaceFixture.lipsCenter.y - 6, width: 56, height: 12)
        #expect(strong.greatestDifference(from: Self.plain.original, in: lips) <= 3, "the lips changed")
        for rect in [CGRect(x: 0, y: 0, width: 60, height: 640), CGRect(x: 420, y: 0, width: 60, height: 640)] {
            #expect(strong.greatestDifference(from: Self.plain.original, in: rect) <= 1, "\(rect) changed")
        }
    }

    @Test func theSmoothingKeepsAnEdgeAndTheStubble() throws {
        func contrast(_ pixels: RenderedPixels) -> Double {
            let crease = SkinFaceFixture.crease
            let above = CGRect(x: crease.minX + 4, y: crease.maxY + 6, width: crease.width - 8, height: 6)
            return luma(pixels, in: above) - luma(pixels, in: crease.insetBy(dx: 4, dy: 1))
        }
        let before = contrast(Self.plain.original)
        #expect(contrast(Self.todaysTop) > before * 0.85, "the crease keeps its contrast: \(before) → \(contrast(Self.todaysTop))")
        let stubble = SkinFaceFixture.stubble
        var speck: CGPoint?
        for x in Int(stubble.minX)..<Int(stubble.maxX) where speck == nil {
            for y in Int(stubble.minY)..<Int(stubble.maxY) where (x * 7 + y * 13) % 5 == 0 { speck = CGPoint(x: x, y: y); break }
        }
        let point = try #require(speck)
        #expect(Self.todaysTop.rgb(at: point).red < 120, "a speck of beard stays dark")
    }

    // MARK: - Off, and a face Vision doubts

    @Test func withEverythingAtZeroTheFrameIsNotEvenLookedAt() {
        let detector = FakeFaceDetector(faces: [SkinFaceFixture.landmarks()])
        let smoother = SkinSmoother(context: Self.context, detector: detector)
        #expect(smoother.pass(for: Self.plain.image, skin: SkinLook(), stream: .main, epoch: 0, time: 0) == nil)
        #expect(smoother.pass(for: Self.plain.image, skin: .smoothing(0, texture: 100), stream: .main, epoch: 0, time: 1) == nil)
        #expect(detector.calls == 0)
        #expect(smoother.pass(for: Self.plain.image, skin: SkinLook(faceLight: 10), stream: .main, epoch: 0, time: 2) != nil, "the light alone is Skin too")
        #expect(smoother.pass(for: Self.plain.image, skin: SkinLook(antiShine: 10), stream: .main, epoch: 0, time: 3) != nil)
    }

    @Test func aFaceVisionDoubtsIsLeftAsItWas() {
        var faces = Self.plain.pass.faces
        for index in faces.indices { faces[index].trust = 0 }
        let look = SkinLook(smoothing: SkinSmoothing(amount: 100, texture: 50), faceLight: 100, antiShine: 100)
        let drawn = RenderedPixels(SkinSmoothingPass(faces: faces).apply(look, to: Self.plain.image))
        #expect(drawn.greatestDifference(from: Self.plain.original, in: wholeFrame) == 0)
    }

    // MARK: - Face light

    @Test func theFaceLightBrightensTheFaceAndKeepsItsColour() {
        let lit = Self.plain.drawn(SkinLook(faceLight: 100))
        let before = Self.plain.original.mean(in: cheek), after = lit.mean(in: cheek)
        #expect(luma(lit, in: cheek) > luma(Self.plain.original, in: cheek) + 6, "the face is lit")
        #expect(abs(after.red / after.green - before.red / before.green) < 0.04, "a light, not a wash of white: the hue stays")
        let halfLit = Self.plain.drawn(SkinLook(faceLight: 50))
        #expect(luma(halfLit, in: cheek) < luma(lit, in: cheek))
    }

    @Test func theFaceLightStaysOnTheFace() {
        let lit = Self.plain.drawn(SkinLook(faceLight: 100))
        for corner in [CGRect(x: 0, y: 0, width: 24, height: 24), CGRect(x: 456, y: 616, width: 24, height: 24), CGRect(x: 456, y: 0, width: 24, height: 24)] {
            #expect(lit.greatestDifference(from: Self.plain.original, in: corner) <= 1, "\(corner) was lit")
        }
        for eye in SkinFaceFixture.eyeCenters {
            let pupil = CGRect(x: eye.x - 2, y: eye.y - 2, width: 4, height: 4)
            #expect(luma(lit, in: pupil) - luma(Self.plain.original, in: pupil) < 6, "the pupils stay dark")
        }
    }

    // MARK: - Anti-shine

    @Test func theAntiShineTakesTheShineDownToTheSkin() {
        let matte = Self.shiny.drawn(SkinLook(antiShine: 100))
        let middle = CGRect(x: Self.shineCenter.x - 3, y: Self.shineCenter.y - 3, width: 6, height: 6)
        let shining = luma(Self.shiny.original, in: middle), after = luma(matte, in: middle)
        #expect(after < shining - 6, "the shine comes down: \(shining) → \(after)")
        let around = CGRect(x: Self.shineCenter.x + 22, y: Self.shineCenter.y - 3, width: 6, height: 6)
        #expect(after > luma(Self.shiny.original, in: around) - 3, "never darker than the skin around it")
        let before = Self.shiny.original.mean(in: middle), now = matte.mean(in: middle)
        #expect(now.red - now.blue > before.red - before.blue, "it comes back to the skin's colour, not grey")
        let half = luma(Self.shiny.drawn(SkinLook(antiShine: 50)), in: middle)
        #expect(half < shining && half > after, "half the dial takes less")
    }

    @Test func theAntiShineLeavesSkinWithNoShineAndTheFeaturesAlone() {
        let matte = Self.shiny.drawn(SkinLook(antiShine: 100))
        #expect(matte.greatestDifference(from: Self.shiny.original, in: CGRect(x: 220, y: 290, width: 60, height: 50)) <= 2, "skin with no shine changed")
        for eye in SkinFaceFixture.eyeCenters {
            #expect(matte.greatestDifference(from: Self.shiny.original, in: CGRect(x: eye.x - 14, y: eye.y - 5, width: 28, height: 10)) <= 3)
        }
        #expect(matte.greatestDifference(from: Self.shiny.original, in: CGRect(x: 0, y: 0, width: 60, height: 640)) == 0)
        let plain = Self.plain.drawn(SkinLook(antiShine: 100))
        #expect(plain.greatestDifference(from: Self.plain.original, in: cheek) <= 2, "a face with no shine is left as it was")
    }
}
