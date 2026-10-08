//
//  FrameGeometryTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The recorded frame on screen and VideoSpace → ScreenSpace, on the screens Cue runs on.
@Suite("FrameGeometry")
struct FrameGeometryTests {
    struct Screen: Sendable, CustomTestStringConvertible {
        let name: String
        let size: CGSize
        var testDescription: String { name }
    }

    static let screens: [Screen] = [
        Screen(name: "iPhone SE", size: CGSize(width: 375, height: 667)),
        Screen(name: "iPhone 15", size: CGSize(width: 393, height: 852)),
        Screen(name: "iPhone 17", size: CGSize(width: 402, height: 874)),
        Screen(name: "iPhone 16 Pro Max", size: CGSize(width: 440, height: 956)),
        Screen(name: "iPad, portrait", size: CGSize(width: 820, height: 1180)),
        Screen(name: "iPad, landscape", size: CGSize(width: 1180, height: 820)),
    ]

    private func geometry(_ aspect: AspectRatio, on screen: CGSize = CGSize(width: 402, height: 874), resolution: VideoResolution = .hd1080) -> FrameGeometry {
        FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: screen), aspect: aspect, resolution: resolution)
    }

    private func isClose(_ a: CGFloat, _ b: CGFloat, within tolerance: CGFloat = 0.01) -> Bool {
        abs(a - b) <= tolerance
    }

    // MARK: - Where the frame sits

    @Test func onTheDesignScreenTheSensorIsFullWidthAndALittleAboveCenter() {
        let sensor = FrameGeometry.sensorRect(in: CGSize(width: 402, height: 874))
        #expect(sensor.minX == 0)
        #expect(sensor.width == 402)
        #expect(isClose(sensor.height, 402 * 16 / 9))
        #expect(isClose(sensor.midY, 401))
    }

    @Test(arguments: screens)
    func theSensorIsAlways9By16AndOnScreen(_ screen: Screen) {
        let sensor = FrameGeometry.sensorRect(in: screen.size)
        #expect(isClose(sensor.width / sensor.height, 9.0 / 16.0))
        #expect(sensor.minX >= 0 && sensor.minY >= 0)
        #expect(sensor.maxX <= screen.size.width + 0.01 && sensor.maxY <= screen.size.height + 0.01)
        // As big as it can be: full width, or full height on wider screens.
        #expect(isClose(sensor.width, screen.size.width) || isClose(sensor.height, screen.size.height))
    }

    @Test(arguments: screens)
    func theFrameIsTheExportCropOfTheSensor(_ screen: Screen) {
        for aspect in AspectRatio.allCases {
            let geometry = geometry(aspect, on: screen.size)
            #expect(isClose(geometry.frameRect.width / geometry.frameRect.height, aspect.widthOverHeight))
            #expect(isClose(geometry.frameRect.midX, geometry.sensorRect.midX))
            #expect(isClose(geometry.frameRect.midY, geometry.sensorRect.midY))
            #expect(geometry.sensorRect.insetBy(dx: -0.01, dy: -0.01).contains(geometry.frameRect))
        }
    }

    @Test func nineBySixteenRecordsTheWholeSensor() {
        let geometry = geometry(.portrait)
        #expect(geometry.frameRect == geometry.sensorRect)
    }

    // MARK: - Filling the screen

    static let phones = screens.filter { $0.name.hasPrefix("iPhone") }

    @Test(arguments: phones)
    func fillingMakesTheSensorAsTallAsThePhoneAndCenteredOnIt(_ screen: Screen) {
        let sensor = FrameGeometry.sensorRect(in: screen.size, fillsScreen: true)
        #expect(isClose(sensor.width / sensor.height, 9.0 / 16.0))
        #expect(isClose(sensor.minY, 0) && isClose(sensor.height, screen.size.height))
        #expect(isClose(sensor.midX, screen.size.width / 2))
        // Nothing of the screen is left empty: the image covers all of it.
        #expect(sensor.insetBy(dx: -0.5, dy: -0.5).contains(CGRect(origin: .zero, size: screen.size)))
    }

    @Test(arguments: screens)
    func notFillingKeepsTheWholeFrameOnScreen(_ screen: Screen) {
        #expect(FrameGeometry.sensorRect(in: screen.size, fillsScreen: false) == FrameGeometry.sensorRect(in: screen.size))
    }

    @Test func aScreenWiderThanNineBySixteenNeverFills() {
        // An iPad would lose a third of the image above and below: it shows the whole thing instead.
        let ipad = CGSize(width: 820, height: 1180)
        #expect(FrameGeometry.sensorRect(in: ipad, fillsScreen: true) == FrameGeometry.sensorRect(in: ipad))
    }

    @Test func fillingKeepsEveryFrameCenteredOnTheScreen() {
        let screen = CGSize(width: 440, height: 956)
        for aspect in AspectRatio.allCases {
            let geometry = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: screen, fillsScreen: true), aspect: aspect, resolution: .hd1080)
            #expect(isClose(geometry.frameRect.midX, screen.width / 2))
            #expect(isClose(geometry.frameRect.midY, screen.height / 2))
        }
    }

    /// What a creator loses sight of on a Pro Max: about 9% of each side (98 of the 1080 px), all of it still in the video.
    @Test func fillingHidesAboutNinePercentOfEachSideOfTheVideo() {
        let screen = CGSize(width: 440, height: 956)
        let geometry = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: screen, fillsScreen: true), aspect: .portrait, resolution: .hd1080)
        let hidden = -geometry.frameRect.minX / geometry.frameRect.width * 1080
        #expect(isClose(hidden, 98, within: 1))
    }

    /// On that screen Reels' left margin (60 px) is under the screen's edge and the right one (120 px) is still on it: the guide's left
    /// line is off screen when the preview fills it, and the full frame shows both.
    @Test func fillingTakesTheLeftSafeLineOffScreenButNotTheRightOne() throws {
        let screen = CGSize(width: 440, height: 956)
        let zone = try #require(TestData.rules.safeZone(for: .reels))
        let full = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: screen), aspect: .portrait, resolution: .hd1080)
        let filled = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: screen, fillsScreen: true), aspect: .portrait, resolution: .hd1080)
        let fullContent = full.toScreen(zone.recommendedContentRect, in: zone.videoSize)
        let filledContent = filled.toScreen(zone.recommendedContentRect, in: zone.videoSize)
        #expect(fullContent.minX > 0 && fullContent.maxX < screen.width)
        #expect(filledContent.minX < 0)
        #expect(filledContent.maxX < screen.width)
    }

    // MARK: - VideoSpace

    @Test(arguments: [
        (AspectRatio.portrait, VideoResolution.hd1080, CGSize(width: 1080, height: 1920)),
        (.vertical, .hd1080, CGSize(width: 1080, height: 1350)),
        (.square, .hd1080, CGSize(width: 1080, height: 1080)),
        (.portrait, .uhd4K, CGSize(width: 2160, height: 3840)),
    ])
    func videoSizeIsTheExportedFrame(_ aspect: AspectRatio, _ resolution: VideoResolution, _ size: CGSize) {
        #expect(geometry(aspect, resolution: resolution).videoSize == size)
    }

    @Test func videoSpaceCornersLandOnTheFrameCorners() {
        let geometry = geometry(.portrait)
        let whole = geometry.toScreen(CGRect(origin: .zero, size: geometry.videoSize))
        #expect(isClose(whole.minX, geometry.frameRect.minX))
        #expect(isClose(whole.minY, geometry.frameRect.minY))
        #expect(isClose(whole.maxX, geometry.frameRect.maxX))
        #expect(isClose(whole.maxY, geometry.frameRect.maxY))
    }

    @Test(arguments: screens)
    func reelsSafeAreaScalesWithTheFrameNotTheScreen(_ screen: Screen) throws {
        let zone = try #require(TestData.rules.safeZone(for: .reels))
        let geometry = geometry(.portrait, on: screen.size)
        let content = geometry.toScreen(zone.recommendedContentRect, in: zone.videoSize)
        let scale = geometry.frameRect.width / 1080
        #expect(isClose(content.minY - geometry.frameRect.minY, 220 * scale))
        #expect(isClose(geometry.frameRect.maxY - content.maxY, 420 * scale))
        #expect(isClose(content.minX - geometry.frameRect.minX, 60 * scale))
        #expect(isClose(geometry.frameRect.maxX - content.maxX, 120 * scale))
    }

    @Test func linkedInSafeAreaUsesThe4By5Frame() throws {
        let zone = try #require(TestData.rules.safeZone(for: .linkedin))
        let geometry = geometry(.vertical)
        let content = geometry.toScreen(zone.recommendedContentRect, in: zone.videoSize)
        #expect(isClose(content.minY, geometry.frameRect.minY))
        #expect(isClose(geometry.frameRect.maxY - content.maxY, 200 * geometry.frameRect.height / 1350))
    }

    @Test func theRealPreviewRectWins() {
        // The preview layer drew the image a little lower than the computed spot.
        let reported = CGRect(x: 0, y: 60, width: 402, height: 402 * 16 / 9)
        let geometry = FrameGeometry(sensorRect: reported, aspect: .portrait, resolution: .hd1080)
        #expect(isClose(geometry.frameRect.minY, 60))
        #expect(isClose(geometry.frameRect.height, reported.height))
        #expect(isClose(geometry.toScreen(.zero).minY, 60))
    }
}
