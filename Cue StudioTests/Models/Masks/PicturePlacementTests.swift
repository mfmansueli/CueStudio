//
//  PicturePlacementTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Where a footage's points land on the frame, and back, as the compositor draws them: a recording through Format's crop, the
/// split screen's main area and the clip's zoom (`FramePlacement`); a photo or video over the take through its place, framing
/// and keyframes (`MediaPicturePlacement`). The handles of Mask and Blur area stand on these.
@Suite("Footage on the frame")
struct PicturePlacementTests {
    @Test func aRecordingsBoxGoesThroughTheCropAndTheZoomAndBack() {
        let size = CGSize(width: 1920, height: 1080)
        var placement = FramePlacement(uprightSize: size, crop: CropMath.crop(in: size, aspect: 9.0 / 16, offset: 0.3))
        placement.zoom = 1.4
        let box = NormalizedBox(x: 0.45, y: 0.3, width: 0.1, height: 0.2)
        let rect = placement.videoRect(for: box, at: 0)
        let back = placement.recordingBox(for: rect, at: 0)
        #expect(abs(back.x - box.x) < 0.000_1 && abs(back.width - box.width) < 0.000_1 && abs(back.y - box.y) < 0.000_1)
        // The zoom makes it bigger on the frame, around the middle.
        var flat = placement
        flat.zoom = 1
        #expect(rect.width > flat.videoRect(for: box, at: 0).width * 1.39)
    }

    @Test func inTheSplitScreensMainAreaTheBoxSitsInThatArea() {
        let size = CGSize(width: 1080, height: 1920)
        var placement = FramePlacement(uprightSize: size, crop: CropMath.crop(in: size, aspect: 9.0 / 16, offset: 0))
        let areas = SplitPlacement.areas(SplitLayout(), in: placement.crop.size)
        placement.area = (areas.main, SplitPlacement.place(size, in: areas.main.size, framing: AreaFraming()))
        let middle = placement.videoPoint(for: CGPoint(x: 0.5, y: 0.5), at: 0)
        let mainOnFrame = CGRect(
            x: areas.main.minX / placement.crop.width, y: areas.main.minY / placement.crop.height,
            width: areas.main.width / placement.crop.width, height: areas.main.height / placement.crop.height
        )
        #expect(abs(middle.x - mainOnFrame.midX) < 0.001 && abs(middle.y - mainOnFrame.midY) < 0.001)
        let back = placement.recordingPoint(for: middle, at: 0)
        #expect(abs(back.x - 0.5) < 0.000_1 && abs(back.y - 0.5) < 0.000_1)
    }

    @Test func aWindowNeverTakesTheFramingItHadAsASupport() {
        var media = MediaOverlay(kind: .photo, fileName: "a.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 0, end: 3))
        media.layout = .window
        // Framed while it was a support: zoomed into a corner.
        media.areaFraming = AreaFraming(zoom: 3, center: OverlayPoint(x: 0.1, y: 0.1))
        let placement = MediaPicturePlacement(media: media, pictureSize: CGSize(width: 1000, height: 1000), frameSize: CGSize(width: 1080, height: 1920))
        let middle = placement.framePoint(forPicture: CGPoint(x: 0.5, y: 0.5))
        let place = placement.framePoint(forPlace: OverlayPoint(x: 0.5, y: 0.5))
        #expect(abs(middle.x - place.x) < 0.001 && abs(middle.y - place.y) < 0.001, "the picture fills its window, centered")
    }

    @Test func aWindowsPictureFollowsItsKeyframesAndFraming() {
        var media = MediaOverlay(kind: .photo, fileName: "a.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 0, end: 3))
        media.layout = .window
        media.width = 0.5
        media.center = OverlayPoint(x: 0.5, y: 0.5)
        media.pictureFraming = AreaFraming(zoom: 2, center: OverlayPoint(x: 0.25, y: 0.25))
        let frame = CGSize(width: 1080, height: 1920)
        let motion = OverlayMotion.State(center: OverlayPoint(x: 0.3, y: 0.6), scale: 1.5, opacity: 1)
        let placement = MediaPicturePlacement(media: media, pictureSize: CGSize(width: 1000, height: 1000), frameSize: frame, motion: motion)
        // The place's middle is where the keyframes put it.
        let middle = placement.framePoint(forPlace: OverlayPoint(x: 0.5, y: 0.5))
        #expect(abs(middle.x - 0.3) < 0.000_1 && abs(middle.y - 0.6) < 0.000_1)
        // Zoomed in on the picture's top left quarter: its point (0.25, 0.25) is in the place's middle.
        let picked = placement.framePoint(forPicture: CGPoint(x: 0.25, y: 0.25))
        #expect(abs(picked.x - 0.3) < 0.001 && abs(picked.y - 0.6) < 0.001)
        let box = NormalizedBox(x: 0.2, y: 0.2, width: 0.1, height: 0.1)
        let back = placement.pictureBox(forFrame: placement.frameRect(forPicture: box))
        #expect(abs(back.x - 0.2) < 0.000_1 && abs(back.height - 0.1) < 0.000_1)
    }
}
