//
//  ClipShapeDrawingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// What the compositor draws for a clip turned, mirrored, cropped (`FramePipeline.oriented`) and animated
/// (`FramePipeline.animated`), where the handles over it go (`FramePlacement`), its thumbnails, and its sound's own fades
/// (`EditedComposition.levels`).
@Suite("Drawing a clip's shape, animation and sound fades")
struct ClipShapeDrawingTests {
    /// A frame 40 wide and 20 tall: red on its left half, blue on its right.
    private var frame: CIImage {
        let red = CIImage(color: CIColor(red: 0.9, green: 0.1, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 20, height: 20))
        let blue = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.9)).cropped(to: CGRect(x: 20, y: 0, width: 20, height: 20))
        return blue.composited(over: red)
    }

    private func isRed(_ color: (red: Double, green: Double, blue: Double)) -> Bool { color.red > 150 && color.blue < 80 }
    private func isBlue(_ color: (red: Double, green: Double, blue: Double)) -> Bool { color.blue > 150 && color.red < 80 }

    @Test func aQuarterTurnStandsTheFrameUpWithItsLeftOnTop() {
        let image = FramePipeline.oriented(frame, by: ClipOrientation(quarterTurns: 1))
        #expect(image.extent == CGRect(x: 0, y: 0, width: 20, height: 40))
        let pixels = RenderedPixels(image)
        // Core Image's y grows upward: the top is high y.
        #expect(isRed(pixels.rgb(at: CGPoint(x: 10, y: 35))))
        #expect(isBlue(pixels.rgb(at: CGPoint(x: 10, y: 5))))
    }

    @Test func mirrorSwapsLeftAndRightAndCropKeepsItsPart() {
        let mirrored = RenderedPixels(FramePipeline.oriented(frame, by: ClipOrientation(isMirrored: true)))
        #expect(isBlue(mirrored.rgb(at: CGPoint(x: 5, y: 10))))
        #expect(isRed(mirrored.rgb(at: CGPoint(x: 35, y: 10))))
        let cropped = FramePipeline.oriented(frame, by: ClipOrientation(crop: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)))
        #expect(cropped.extent == CGRect(x: 0, y: 0, width: 20, height: 20))
        #expect(isBlue(RenderedPixels(cropped).rgb(at: CGPoint(x: 10, y: 10))))
    }

    @Test func aFadeStartsOnBlackAndASlideComesInFromTheSide() {
        let faded = FramePipeline.animated(frame, ClipAnimationFrame(opacity: 0))
        let black = RenderedPixels(faded).rgb(at: CGPoint(x: 10, y: 10))
        #expect(black.red < 10 && black.blue < 10)
        #expect(faded.extent == frame.extent)
        // Halfway in from the left: the frame's right half shows on the left, black where the rest is still to come.
        let sliding = RenderedPixels(FramePipeline.animated(frame, ClipAnimationFrame(dx: -0.5)))
        #expect(isBlue(sliding.rgb(at: CGPoint(x: 5, y: 10))))
        let empty = sliding.rgb(at: CGPoint(x: 30, y: 10))
        #expect(empty.red < 10 && empty.blue < 10)
    }

    /// Blur area's handles and what Track follows sit where `FramePipeline.animated` draws the point of the picture under them.
    @Test func theHandlesFollowTheAnimationAsItIsDrawn() {
        let size = CGSize(width: 1080, height: 1920)
        let crop = CropMath.crop(in: size, aspect: 1, offset: 0)
        let still = FramePlacement(uprightSize: size, crop: crop)
        var moving = still
        moving.animation = ClipAnimationFrame(dx: 0.25, dy: 0.1, scale: 0.8)
        let point = CGPoint(x: 0.3, y: 0.45)
        let before = still.videoPoint(for: point, at: 0)
        // `FramePipeline.animated`'s transform on the frame, in Core Image's coordinates (y up).
        let frame = crop.size
        let transform = CGAffineTransform(translationX: -frame.width / 2, y: -frame.height / 2)
            .concatenating(CGAffineTransform(scaleX: 0.8, y: 0.8))
            .concatenating(CGAffineTransform(translationX: frame.width / 2 + 0.25 * frame.width, y: frame.height / 2 - 0.1 * frame.height))
        let drawn = CGPoint(x: before.x * frame.width, y: frame.height - before.y * frame.height).applying(transform)
        let after = moving.videoPoint(for: point, at: 0)
        #expect(abs(after.x - drawn.x / frame.width) < 0.000_1)
        #expect(abs(after.y - (frame.height - drawn.y) / frame.height) < 0.000_1)
        let back = moving.recordingPoint(for: after, at: 0)
        #expect(abs(back.x - point.x) < 0.000_1 && abs(back.y - point.y) < 0.000_1)
    }

    @Test func aMomentOfTheClipTakesItsZoomAndAnimationThen() {
        var clip = EditSegment(sourceStart: 0, sourceEnd: 4, zoom: .pushIn)
        clip.animationIn = ClipAnimation(style: .slide, duration: 0.5)
        let placement = FramePlacement(uprightSize: CGSize(width: 1080, height: 1920), crop: CGRect(x: 0, y: 0, width: 1080, height: 1920))
        #expect(placement.moment(of: clip, startingAt: 10, at: 10).animation.dx == -1)
        #expect(placement.moment(of: clip, startingAt: 10, at: 12).animation == .still)
        #expect(placement.moment(of: clip, startingAt: 10, at: 13.9).zoom > 1)
        #expect(placement.moment(of: EditSegment(sourceStart: 0, sourceEnd: 4), startingAt: 10, at: 10).animation == .still)
    }

    @Test func aThumbnailIsTurnedMirroredAndCroppedAsTheClip() throws {
        let picture = try #require(CIContext().createCGImage(frame, from: frame.extent))
        let thumbnail = UIImage(cgImage: picture)
        let turned = thumbnail.shaped(by: ClipOrientation(quarterTurns: 1))
        #expect(turned.size == CGSize(width: 20, height: 40))
        let half = thumbnail.shaped(by: ClipOrientation(crop: CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        #expect(half.size == CGSize(width: 20, height: 20))
        #expect(thumbnail.shaped(by: .identity) === thumbnail)
    }

    @Test func aClipsSoundFadesInAndOutAndTheNextComesBack() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        var first = timeline.segments[0]
        first.soundFadeIn = 1
        first.soundFadeOut = 2
        timeline.replaceSegment(first)
        let levels = EditedComposition.levels(for: timeline) { _ in true }
        #expect(levels.contains(EditedComposition.Fade(start: 0, duration: 1, fromVolume: 0, toVolume: 1)))
        #expect(levels.contains(EditedComposition.Fade(start: 8, duration: 2, fromVolume: 1, toVolume: 0)))
        // The second clip runs on from it: its sound comes straight back.
        #expect(levels.contains { $0.start == 10 && $0.fromVolume == 0 && $0.toVolume == 1 && $0.duration <= EditedComposition.cutFade })
        // Ramps never overlap.
        for (one, next) in zip(levels, levels.dropFirst()) {
            #expect(one.start + one.duration <= next.start + 0.000_1)
        }
    }

    @Test func fadesLongerThanTheClipShareIt() {
        var timeline = EditTimeline(sourceDuration: 3)
        var clip = timeline.segments[0]
        clip.soundFadeIn = 2
        clip.soundFadeOut = 2
        timeline.replaceSegment(clip)
        let levels = EditedComposition.levels(for: timeline) { _ in true }
        #expect(levels.reduce(0) { $0 + $1.duration } <= 3.000_1)
    }
}
