//
//  SkinSmoothingFilterTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// The smoothing itself, on a drawn face rendered by the software renderer: it softens skin texture and nothing else, keeps the eyes, brows, lips,
/// hair, beard and edges, doesn't whiten or shift color, and does less at a lower dial.
@Suite("Skin Smoothing filter", .serialized, .timeLimit(.minutes(5)))
struct SkinSmoothingFilterTests {
    private static let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])

    /// The drawn face, found by a fake detector, smoothed at each value asked for.
    private struct Rendered {
        let original: RenderedPixels
        let results: [Double: RenderedPixels]

        init(texture: Double = 1, skin: Double = 1, scale: CGFloat = 1, values: [Double]) {
            var image = SkinFaceFixture.image(texture: texture, skin: skin)
            if scale != 1 { image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
            let smoother = SkinSmoother(context: SkinSmoothingFilterTests.context, detector: FakeFaceDetector(faces: [SkinFaceFixture.landmarks()]))
            let pass = smoother.pass(for: image, stream: .main, epoch: 0, time: 0)
            original = RenderedPixels(image)
            results = Dictionary(uniqueKeysWithValues: values.map { ($0, RenderedPixels(pass.apply(value: $0, to: image))) })
        }
    }

    private static let standard = Rendered(values: [25, 50, 100])

    private let cheek = SkinFaceFixture.cheek

    // MARK: - What it softens

    @Test func softensTheSkinsTextureButDoesNotErase() throws {
        let before = Self.standard.original.texture(in: cheek)
        let after = try #require(Self.standard.results[100]).texture(in: cheek)
        #expect(after < before * 0.85, "the grain and the blemishes are softened: \(before) → \(after)")
        #expect(after > before * 0.35, "…but the skin is not wiped to plastic: \(before) → \(after)")
    }

    @Test func aHigherDialSoftensMore() throws {
        let weak = try #require(Self.standard.results[25]).texture(in: cheek)
        let middle = try #require(Self.standard.results[50]).texture(in: cheek)
        let strong = try #require(Self.standard.results[100]).texture(in: cheek)
        #expect(Self.standard.original.texture(in: cheek) > weak && weak > middle && middle > strong)
    }

    @Test func doesNotWhitenOrShiftTheColor() throws {
        let strong = try #require(Self.standard.results[100])
        for rect in [cheek, CGRect(x: 200, y: 300, width: 80, height: 60), CGRect(x: 205, y: 430, width: 70, height: 40)] {
            let before = Self.standard.original.mean(in: rect), after = strong.mean(in: rect)
            #expect(abs(after.red - before.red) < 1.5 && abs(after.green - before.green) < 1.5 && abs(after.blue - before.blue) < 1.5)
        }
    }

    @Test func doesNotBleedTheHairIntoTheSkinBesideIt() throws {
        let strong = try #require(Self.standard.results[100])
        let edge = CGRect(x: 112, y: 300, width: 18, height: 40)
        let before = Self.standard.original.mean(in: edge), after = strong.mean(in: edge)
        #expect(abs(after.red - before.red) < 3 && abs(after.green - before.green) < 3 && abs(after.blue - before.blue) < 3)
    }

    // MARK: - What it keeps

    @Test func leavesTheEyesTheBrowsAndTheLipsAlone() throws {
        let strong = try #require(Self.standard.results[100])
        for eye in SkinFaceFixture.eyeCenters {
            let rect = CGRect(x: eye.x - 14, y: eye.y - 5, width: 28, height: 10)
            #expect(strong.greatestDifference(from: Self.standard.original, in: rect) <= 3, "an eye changed")
        }
        for line in SkinFaceFixture.browLines {
            let rect = CGRect(x: (line.0.x + line.1.x) / 2 - 15, y: (line.0.y + line.1.y) / 2 - 3, width: 30, height: 6)
            #expect(strong.greatestDifference(from: Self.standard.original, in: rect) <= 3, "a brow changed")
        }
        let lips = CGRect(x: SkinFaceFixture.lipsCenter.x - 28, y: SkinFaceFixture.lipsCenter.y - 6, width: 56, height: 12)
        #expect(strong.greatestDifference(from: Self.standard.original, in: lips) <= 3, "the lips changed")
    }

    @Test func leavesTheHairTheBackgroundAndEverythingOutsideTheFaceExactlyAsItWas() throws {
        let strong = try #require(Self.standard.results[100])
        let borders = [
            CGRect(x: 0, y: 0, width: 60, height: 640), CGRect(x: 420, y: 0, width: 60, height: 640),
            CGRect(x: 0, y: 0, width: 480, height: 60), CGRect(x: 0, y: 590, width: 480, height: 50),
        ]
        for rect in borders {
            #expect(strong.greatestDifference(from: Self.standard.original, in: rect) <= 1, "\(rect) changed")
        }
    }

    @Test func keepsAnEdgeFarStrongerThanTexture() throws {
        let strong = try #require(Self.standard.results[100])
        func contrast(_ pixels: RenderedPixels) -> Double {
            let crease = SkinFaceFixture.crease
            let on = pixels.luma(in: crease.insetBy(dx: 4, dy: 1)).reduce(0, +) / Double(pixels.luma(in: crease.insetBy(dx: 4, dy: 1)).count)
            let above = CGRect(x: crease.minX + 4, y: crease.maxY + 6, width: crease.width - 8, height: 6)
            let off = pixels.luma(in: above).reduce(0, +) / Double(pixels.luma(in: above).count)
            return off - on
        }
        let before = contrast(Self.standard.original)
        #expect(before > 40)
        #expect(contrast(strong) > before * 0.85, "the crease keeps its contrast: \(before) → \(contrast(strong))")
    }

    @Test func keepsTheStubbleOnTheChin() throws {
        let strong = try #require(Self.standard.results[100])
        let stubble = SkinFaceFixture.stubble
        var speck: CGPoint?
        for x in Int(stubble.minX)..<Int(stubble.maxX) where speck == nil {
            for y in Int(stubble.minY)..<Int(stubble.maxY) where (x * 7 + y * 13) % 5 == 0 { speck = CGPoint(x: x, y: y); break }
        }
        let point = try #require(speck)
        let before = Self.standard.original.rgb(at: point), after = strong.rgb(at: point)
        #expect(abs(before.red - after.red) < 25, "a speck of beard stays dark: \(before) → \(after)")
        #expect(after.red < 120)
    }

    // MARK: - Off, and not on

    @Test func atZeroTheImageComesBackAsItWas() throws {
        let image = SkinFaceFixture.image()
        let smoother = SkinSmoother(context: Self.context, detector: FakeFaceDetector(faces: [SkinFaceFixture.landmarks()]))
        let pass = smoother.pass(for: image, stream: .main, epoch: 0, time: 0)
        #expect(!pass.faces.isEmpty)
        let result = pass.apply(value: 0, to: image)
        #expect(result.extent == image.extent)
        #expect(RenderedPixels(result).greatestDifference(from: RenderedPixels(image), in: CGRect(origin: .zero, size: SkinFaceFixture.size)) == 0)
    }

    @Test func aFrameWithNoFaceComesBackAsItWas() {
        let image = SkinFaceFixture.image()
        let result = SkinSmoothingPass.none.apply(value: 100, to: image)
        #expect(RenderedPixels(result).greatestDifference(from: RenderedPixels(image), in: CGRect(origin: .zero, size: SkinFaceFixture.size)) == 0)
    }

    @Test func aFaceThatIsNotThereYetChangesNothingAndHalfThereChangesHalf() throws {
        let image = SkinFaceFixture.image()
        let smoother = SkinSmoother(context: Self.context, detector: FakeFaceDetector(faces: [SkinFaceFixture.landmarks()]))
        let pass = smoother.pass(for: image, stream: .main, epoch: 0, time: 0)
        func texture(at presence: Double) -> Double {
            var faces = pass.faces
            for index in faces.indices { faces[index].presence = presence }
            return RenderedPixels(SkinSmoothingPass(faces: faces).apply(value: 100, to: image)).texture(in: cheek)
        }
        let none = texture(at: 0), half = texture(at: 0.5), full = texture(at: 1)
        #expect(none == Self.standard.original.texture(in: cheek))
        #expect(full < half && half < none)
    }

    // MARK: - Skin tones, light, size

    @Test func darkSkinIsSmoothedAndKeepsItsTone() throws {
        let dark = Rendered(skin: 0.45, values: [100])
        let strong = try #require(dark.results[100])
        #expect(strong.texture(in: cheek) < dark.original.texture(in: cheek) * 0.95)
        let before = dark.original.mean(in: cheek), after = strong.mean(in: cheek)
        #expect(abs(after.red - before.red) < 1.5 && abs(after.green - before.green) < 1.5)
        for eye in SkinFaceFixture.eyeCenters {
            #expect(strong.greatestDifference(from: dark.original, in: CGRect(x: eye.x - 14, y: eye.y - 5, width: 28, height: 10)) <= 3)
        }
    }

    @Test func aDimNoisyShotIsSmoothedToo() throws {
        let dim = Rendered(texture: 3, skin: 0.4, values: [100])
        let strong = try #require(dim.results[100])
        #expect(strong.texture(in: cheek) < dim.original.texture(in: cheek) * 0.9, "noise counts as texture, not as detail to keep")
    }

    @Test func aFrameTwiceTheSizeIsSmoothedTheSameWay() throws {
        let big = Rendered(scale: 2, values: [100])
        let strong = try #require(big.results[100])
        let area = CGRect(x: cheek.minX * 2, y: cheek.minY * 2, width: cheek.width * 2, height: cheek.height * 2)
        #expect(strong.texture(in: area) < big.original.texture(in: area) * 0.95)
        let eye = SkinFaceFixture.eyeCenters[0]
        #expect(strong.greatestDifference(from: big.original, in: CGRect(x: eye.x * 2 - 28, y: eye.y * 2 - 10, width: 56, height: 20)) <= 3)
    }

    @Test func twoFacesAreBothSmoothed() throws {
        let wide = CGSize(width: 960, height: 640)
        let left = SkinFaceFixture.image()
        let right = SkinFaceFixture.image(shiftedBy: .zero).transformed(by: CGAffineTransform(translationX: 480, y: 0))
        let frame = right.composited(over: left).cropped(to: CGRect(origin: .zero, size: wide))
        let detector = FakeFaceDetector(faces: [SkinFaceFixture.landmarks(in: wide), SkinFaceFixture.landmarks(shiftedBy: CGPoint(x: 480, y: 0), in: wide)])
        let pass = SkinSmoother(context: Self.context, detector: detector).pass(for: frame, stream: .main, epoch: 0, time: 0)
        #expect(pass.faces.count == 2)
        let before = RenderedPixels(frame), after = RenderedPixels(pass.apply(value: 100, to: frame))
        for offset in [0.0, 480] {
            let area = CGRect(x: cheek.minX + offset, y: cheek.minY, width: cheek.width, height: cheek.height)
            #expect(after.texture(in: area) < before.texture(in: area) * 0.85, "the face at \(offset) isn't smoothed")
            let eye = SkinFaceFixture.eyeCenters[0]
            #expect(after.greatestDifference(from: before, in: CGRect(x: eye.x + offset - 14, y: eye.y - 5, width: 28, height: 10)) <= 3)
        }
    }
}
