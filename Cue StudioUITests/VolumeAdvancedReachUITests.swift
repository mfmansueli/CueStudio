//
//  VolumeAdvancedReachUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Volume › Advanced reached whole (owner, canvas 2, 07/11/2026: "evidência de que Volume › Avançado pode ser alcançado por
/// inteiro"): a clip's Fade in and Fade out both show whole in the panel once Advanced opens (the panel grows for them); the
/// music's, under its lowering, are reached whole by scrolling the panel to its end.
@MainActor
final class VolumeAdvancedReachUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// Whether `element` sits whole inside the open Volume panel.
    private func isWhole(_ element: XCUIElement) -> Bool {
        let panel = app.descendants(matching: .any)["edit.panel.volume"].frame
        let frame = element.frame
        return element.exists && frame.minY >= panel.minY && frame.maxY <= panel.maxY && frame.height > 20
    }

    func testAClipsFadesShowWholeOnceAdvancedOpens() {
        app = EditorApp.open(demo: true)
        EditorApp.mainTrack(app, at: 0.5).tap()
        EditorApp.tapTool(app, "volume")
        let advanced = app.buttons["edit.panel.advanced"]
        XCTAssertTrue(advanced.exists(within: 5), "No Advanced in the clip's Volume")
        advanced.tap()
        let fadeIn = app.descendants(matching: .any)["edit.clipFadeIn"]
        let fadeOut = app.descendants(matching: .any)["edit.clipFadeOut"]
        XCTAssertTrue(fadeOut.exists(within: 5))
        // The panel grows as it opens: give it its animation.
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(isWhole(fadeIn), "Fade in isn't whole in the panel: \(fadeIn.frame)")
        XCTAssertTrue(isWhole(fadeOut), "Fade out isn't whole in the panel: \(fadeOut.frame)")
        EditorApp.capture(app, "volume-clip-advanced-whole")
    }

    func testTheMusicsFadesAreReachedWholeAtTheEndOfThePanel() {
        app = EditorApp.open(demo: true)
        EditorApp.showEveryTrack(app)
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        let y = EditorApp.trackMiddle(3, of: 5, in: timeline)
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 66, dy: y)).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.beats"].exists(within: 5), "The music isn't picked")
        EditorApp.tapTool(app, "volume")
        let panel = app.descendants(matching: .any)["edit.panel.volume"]
        let advanced = app.buttons["edit.panel.advanced"]
        for _ in 0..<3 where !advanced.isHittable { panel.swipeUp(velocity: .slow) }
        XCTAssertTrue(advanced.isHittable, "Advanced isn't reachable in the music's Volume")
        advanced.tap()
        let fadeIn = app.descendants(matching: .any)["edit.musicFadeIn"]
        let fadeOut = app.descendants(matching: .any)["edit.musicFadeOut"]
        XCTAssertTrue(fadeOut.exists(within: 5))
        for _ in 0..<4 where !isWhole(fadeOut) { panel.swipeUp(velocity: .slow) }
        XCTAssertTrue(isWhole(fadeOut), "The music's Fade out can't be scrolled whole into the panel: \(fadeOut.frame)")
        for _ in 0..<4 where !isWhole(fadeIn) { panel.swipeDown(velocity: .slow) }
        XCTAssertTrue(isWhole(fadeIn), "The music's Fade in can't be scrolled whole into the panel: \(fadeIn.frame)")
        EditorApp.capture(app, "volume-music-advanced-reach")
    }
}
