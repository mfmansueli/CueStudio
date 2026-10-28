//
//  ClipShapeTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Rotate, Mirror and Crop of a clip (`ClipOrientation`, `ClipCrop`) and its Animation (`ClipAnimation`): where a point of the
/// recording shows once the clip is reshaped and back, the box kept inside the picture and at its shape, a way in or out that
/// starts and ends where it should, and old clips read as filmed.
@Suite("A clip's shape and animation")
struct ClipShapeTests {
    private func close(_ first: CGPoint, _ second: CGPoint) -> Bool {
        abs(first.x - second.x) < 0.000_1 && abs(first.y - second.y) < 0.000_1
    }

    @Test func aQuarterTurnTakesTheTopLeftToTheTopRightAndMirrorAcross() {
        let turned = ClipOrientation(quarterTurns: 1)
        #expect(close(turned.shownPoint(CGPoint(x: 0, y: 0)), CGPoint(x: 1, y: 0)))
        #expect(close(turned.shownPoint(CGPoint(x: 1, y: 1)), CGPoint(x: 0, y: 1)))
        // Mirror flips what then shows, left to right.
        let both = ClipOrientation(quarterTurns: 1, isMirrored: true)
        #expect(close(both.shownPoint(CGPoint(x: 0, y: 0)), CGPoint(x: 0, y: 0)))
        #expect(turned.size(of: CGSize(width: 1080, height: 1920)) == CGSize(width: 1920, height: 1080))
        #expect(ClipOrientation(quarterTurns: 5) == ClipOrientation(quarterTurns: 1))
        #expect(ClipOrientation(quarterTurns: -1).quarterTurns == 3)
    }

    @Test func everyShapeTakesAPointThereAndBack() {
        let point = CGPoint(x: 0.3, y: 0.7)
        for turns in 0..<4 {
            for mirrored in [false, true] {
                for crop in [nil, CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6)] {
                    let orientation = ClipOrientation(quarterTurns: turns, isMirrored: mirrored, crop: crop)
                    #expect(close(orientation.uprightPoint(orientation.shownPoint(point)), point), "\(orientation)")
                }
            }
        }
    }

    @Test func aCropKeepsItsPartOfThePictureAndSaysWhichPartOfTheFrameAsFilmed() {
        let orientation = ClipOrientation(quarterTurns: 1, crop: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        #expect(orientation.size(of: CGSize(width: 1080, height: 1920)) == CGSize(width: 960, height: 1080))
        // The left half of the turned picture is the bottom half of the frame as filmed.
        let part = orientation.uprightCrop ?? .zero
        #expect(abs(part.minY - 0.5) < 0.000_1 && abs(part.height - 0.5) < 0.000_1 && abs(part.width - 1) < 0.000_1)
        // A face outside the crop isn't there to follow.
        #expect(orientation.shownBox(NormalizedBox(x: 0.4, y: 0.1, width: 0.2, height: 0.1)) == nil)
        #expect(orientation.shownBox(NormalizedBox(x: 0.4, y: 0.8, width: 0.2, height: 0.1)) != nil)
    }

    @Test func aBoxOfAShapeIsAsBigAsItCanBeInTheMiddle() {
        let square = ClipCrop.centered(.square, in: CGSize(width: 1080, height: 1920)).rect
        #expect(abs(square.width - 1) < 0.000_1)
        #expect(abs(square.height - 1080.0 / 1920) < 0.000_1)
        #expect(abs(square.midY - 0.5) < 0.000_1)
        #expect(ClipCrop.centered(nil, in: CGSize(width: 1080, height: 1920)).isWhole)
    }

    @Test func pullingACornerKeepsTheShapeAndStaysInThePicture() {
        let aspect = 1080.0 / 1920
        let start = ClipCrop.centered(.square, in: CGSize(width: 1080, height: 1920))
        let pulled = start.pulling(.topLeading, to: CGPoint(x: 0.4, y: 0.4), aspect: aspect).rect
        // Still square in pixels: its share of the width times 1080 is its share of the height times 1920.
        #expect(abs(pulled.width * 1080 - pulled.height * 1920) < 0.5)
        // The opposite corner didn't move.
        #expect(abs(pulled.maxX - start.rect.maxX) < 0.000_1 && abs(pulled.maxY - start.rect.maxY) < 0.000_1)
        // Pulled far past the picture, it stops at its edge.
        let far = start.pulling(.bottomTrailing, to: CGPoint(x: 3, y: 3), aspect: aspect).rect
        #expect(far.maxX <= 1.000_1 && far.maxY <= 1.000_1)
        // A free box takes any shape, never thinner than the smallest side.
        let free = ClipCrop(CGRect(x: 0, y: 0, width: 1, height: 1)).pulling(.bottomTrailing, to: CGPoint(x: 0.6, y: 0.01), aspect: aspect).rect
        #expect(abs(free.width - 0.6) < 0.000_1 && abs(free.height - ClipCrop.smallestSide) < 0.000_1)
    }

    @Test func movingTheBoxStopsAtTheEdgesAndMirrorKeepsItsPart() {
        let box = ClipCrop(CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        #expect(box.moved(by: CGSize(width: 2, height: -2)).rect == CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        #expect(abs(box.mirrored.rect.minX - 0.4) < 0.000_1)
    }

    @Test func theWayInAndOutStartAndEndWhereTheyShould() {
        for style in ClipAnimationStyle.allCases {
            let settled = ClipAnimation.frame(style, isIn: true, elapsed: 0.5, length: 0.5)
            #expect(settled == .still, "\(style) settles on the clip as it is")
        }
        #expect(ClipAnimation.frame(.fade, isIn: true, elapsed: 0, length: 0.5).opacity == 0)
        #expect(ClipAnimation.frame(.slide, isIn: true, elapsed: 0, length: 0.5).dx == -1)
        #expect(ClipAnimation.frame(.slide, isIn: false, elapsed: 0, length: 0.5).dx == 1)
        #expect(ClipAnimation.frame(.zoom, isIn: false, elapsed: 0, length: 0.5).scale == 0.75)
        #expect(ClipAnimation(style: .fade, duration: 9).duration == ClipAnimation.durationRange.upperBound)
    }

    @Test func aWindowAnimatesOnlyTheClipsEndsAndShareAShortOne() {
        let window = ClipAnimationWindow(
            start: 10, duration: 4, entrance: ClipAnimation(style: .fade, duration: 1), exit: ClipAnimation(style: .zoom, duration: 1)
        )
        #expect(window.state(at: 10)?.opacity == 0)
        #expect(window.state(at: 12) == nil)
        #expect(window.state(at: 14)?.scale == 0.75)
        // A clip shorter than both: each gets half of it.
        let short = ClipAnimationWindow(
            start: 0, duration: 1, entrance: ClipAnimation(style: .fade, duration: 1.5), exit: ClipAnimation(style: .fade, duration: 1.5)
        )
        #expect(short.state(at: 0.5) == nil)
        #expect((short.state(at: 0.25)?.opacity ?? 1) < 1)
        #expect((short.state(at: 0.75)?.opacity ?? 1) < 1)
    }

    @Test func aSplitKeepsTheWayInOnTheFirstPartAndTheWayOutOnTheLast() {
        var clip = EditSegment(sourceStart: 0, sourceEnd: 10)
        clip.animationIn = ClipAnimation(style: .fade)
        clip.animationOut = ClipAnimation(style: .slide)
        clip.soundFadeIn = 1
        clip.soundFadeOut = 2
        clip.isMirrored = true
        let first = clip.piece(TimeSpan(start: 0, end: 4))
        let last = clip.piece(TimeSpan(start: 4, end: 10))
        #expect(first.animationIn != nil && first.animationOut == nil && first.soundFadeIn == 1 && first.soundFadeOut == 0)
        #expect(last.animationIn == nil && last.animationOut != nil && last.soundFadeIn == 0 && last.soundFadeOut == 2)
        #expect(first.isMirrored && last.isMirrored)
    }

    @Test func aClipKeepsItsShapeWhenSavedAndOldOnesReadAsFilmed() throws {
        var clip = EditSegment(sourceStart: 1, sourceEnd: 5)
        clip.quarterTurns = 3
        clip.isMirrored = true
        clip.crop = ClipCrop(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4), ratio: .square)
        clip.animationIn = ClipAnimation(style: .blur, duration: 0.8)
        clip.soundFadeOut = 1.5
        let saved = try JSONEncoder().encode(clip)
        #expect(try JSONDecoder().decode(EditSegment.self, from: saved) == clip)
        let old = Data(#"{"id":"\#(UUID().uuidString)","sourceStart":0,"sourceEnd":5}"#.utf8)
        let read = try JSONDecoder().decode(EditSegment.self, from: old)
        #expect(read.orientation.isIdentity && !read.animates && read.soundFadeIn == 0 && read.soundFadeOut == 0)
    }

    @Test func resetClipPutsItBackAsFilmedButKeepsItsPlaceAndTransition() {
        var clip = EditSegment(sourceStart: 2, sourceEnd: 8, transitionIn: .dissolve, speed: 2, zoom: .pushIn)
        clip.volume = 0.4
        clip.isMuted = true
        clip.quarterTurns = 1
        clip.animationOut = ClipAnimation(style: .fade)
        clip.stabilization = .strong
        let reset = clip.asRecorded(keepsMute: false)
        #expect(reset == EditSegment(id: clip.id, sourceStart: 2, sourceEnd: 8, transitionIn: .dissolve))
        #expect(clip.asRecorded(keepsMute: true).isMuted)
    }
}
