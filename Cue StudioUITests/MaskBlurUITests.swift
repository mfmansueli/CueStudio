//
//  MaskBlurUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Mask and Blur area in the editor, as a creator reaches them: Blur area from the main toolbar (the faces found, else an area
/// drawn, its panel with what it covers first, a solid bar, its own tools all whole beside Delete, deleted by its ✕ on the
/// preview), and Mask on the demo's video in a window (shapes, the real outline with its handles, Invert, what a drag moves; a
/// small mask with its handles a finger apart). With `TEST_RUNNER_CUE_SCREENSHOT_DIR` set, each step is photographed there.
final class MaskBlurUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testABlurAreaIsDrawnStyledAndDeleted() throws {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "blurArea")
        XCTAssertTrue(app.descendants(matching: .any)["edit.panel.blur"].exists(within: 5), "No Blur area panel")
        let draw = app.buttons["edit.blur.draw"]
        XCTAssertTrue(draw.exists(within: 10), "No way to draw an area")
        snapshot(app, "blur-1-choose")
        draw.tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.blur.status"].exists(within: 5), "No status in the panel")
        XCTAssertTrue(app.descendants(matching: .any)["edit.blur.handle"].exists(within: 5), "No box on the preview")
        XCTAssertTrue(app.buttons["edit.blur.follow"].exists, "A drawn area should offer Track")
        snapshot(app, "blur-2-area")
        app.buttons["edit.blur.style.pixelate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.blur.strength"].exists(within: 3), "Pixelate has a strength")
        snapshot(app, "blur-3-pixelate")
        // The panel closed, the area's own tools: all four whole, none under the pinned Delete.
        app.buttons["edit.panel.apply"].tap()
        let delete = app.buttons["edit.toolbar.delete"]
        XCTAssertTrue(delete.exists(within: 5), "No Delete for the picked area")
        for id in ["editBlur", "followBlur", "reviewBlur", "addBlur"] {
            let tool = app.buttons["edit.toolbar.\(id)"]
            XCTAssertTrue(tool.exists && tool.isHittable, "\(id) isn't reachable")
            XCTAssertLessThanOrEqual(tool.frame.maxX, delete.frame.minX + 1, "\(id) hides under Delete")
        }
        snapshot(app, "blur-4-tools")
        app.buttons["edit.blur.delete"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.blur.handle"].isGone(within: 5), "The box stayed after ✕")
    }

    @MainActor
    func testAMaskGoesOnTheVideoInAWindow() throws {
        let app = EditorApp.open(demo: true)
        // To about 6.8 s, inside the B-roll's window (4.2–8 s): slowly, so a loaded Simulator doesn't glide on past it.
        EditorApp.scrub(app, velocity: 250)
        let window = app.buttons["edit.mediaHandle"]
        XCTAssertTrue(window.exists(within: 5), "No video in a window at the playhead")
        window.tap()
        EditorApp.tapTool(app, "mask")
        XCTAssertTrue(app.descendants(matching: .any)["edit.panel.mask"].exists(within: 5), "No Mask panel")
        snapshot(app, "mask-1-shapes")
        app.buttons["edit.maskShape.circle"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.mask.area"].exists(within: 5), "No mask on the preview")
        XCTAssertTrue(app.descendants(matching: .any)["edit.mask.handle.turn"].exists, "No turn handle")
        XCTAssertTrue(app.descendants(matching: .any)["edit.mask.handle.feather"].exists, "No soft-edge handle")
        snapshot(app, "mask-2-circle")
        app.buttons["edit.maskShape.rectangle"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.mask.handle.corners"].exists(within: 3), "A rectangle rounds its corners")
        app.buttons["edit.maskDrag.picture"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.mask.handle.turn"].isGone(within: 3), "In Picture the mask's handles step aside")
        snapshot(app, "mask-3-picture")
        // Invert is under the first view of the panel: its content scrolls.
        let invert = app.descendants(matching: .any)["edit.maskInvert"]
        let panel = app.descendants(matching: .any)["edit.panel.mask"]
        var swipes = 0
        while !(invert.exists && invert.isHittable), swipes < 3 {
            panel.swipeUp()
            swipes += 1
        }
        invert.tap()
        XCTAssertTrue(["On", "1"].contains(invert.value as? String ?? ""), "Invert didn’t turn on: \(String(describing: invert.value))")
        snapshot(app, "mask-4-inverted")
    }

    @MainActor
    func testASmallMaskKeepsItsHandlesAFingerApart() throws {
        let app = EditorApp.open(demo: true)
        // To about 6.8 s, inside the B-roll's window (4.2–8 s): slowly, so a loaded Simulator doesn't glide on past it.
        EditorApp.scrub(app, velocity: 250)
        let window = app.buttons["edit.mediaHandle"]
        XCTAssertTrue(window.exists(within: 5), "No video in a window at the playhead")
        window.tap()
        EditorApp.tapTool(app, "mask")
        app.buttons["edit.maskShape.rectangle"].tap()
        // Advanced › Size, smaller step by step: a mask a few fingers wide.
        let panel = app.descendants(matching: .any)["edit.panel.mask"]
        let advanced = app.buttons["edit.maskAdvanced"]
        var swipes = 0
        while !(advanced.exists && advanced.isHittable), swipes < 4 {
            panel.swipeUp()
            swipes += 1
        }
        advanced.tap()
        let smaller = app.buttons["edit.maskSize.minus"]
        swipes = 0
        while !(smaller.exists && smaller.isHittable), swipes < 4 {
            panel.swipeUp()
            swipes += 1
        }
        for _ in 0..<40 where smaller.isEnabled { smaller.tap() }
        snapshot(app, "mask-5-small")
        let handles = ["right", "left", "bottom", "top", "turn", "feather", "corners"]
            .map { app.descendants(matching: .any)["edit.mask.handle.\($0)"] }
            .filter(\.exists)
        XCTAssertGreaterThanOrEqual(handles.count, 5, "A small rectangle keeps a tab each way, ↻, the soft edge and its corners")
        for (index, handle) in handles.enumerated() {
            for other in handles[(index + 1)...] {
                let dx = handle.frame.midX - other.frame.midX, dy = handle.frame.midY - other.frame.midY
                XCTAssertGreaterThanOrEqual((dx * dx + dy * dy).squareRoot(), 43, "\(handle.identifier) crowds \(other.identifier)")
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        // On a device, kept in the result bundle (`TEST_RUNNER_CUE_KEEP_SHOTS=1`).
        if ProcessInfo.processInfo.environment["CUE_KEEP_SHOTS"] != nil {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }
}
