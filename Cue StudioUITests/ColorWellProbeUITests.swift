//
//  ColorWellProbeUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Diagnostic: does a tap on a color well open the system's color picker (kit editor, and a text's Color tab)?
@MainActor
final class ColorWellProbeUITests: XCTestCase {
    func testTappingAWellOpensThePicker() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "smart")
        app.buttons["edit.smart.section.brand"].tap()
        app.buttons["edit.brand.newKit"].tap()
        XCTAssertTrue(app.buttons["edit.brand.addColor"].exists(within: 5))
        app.buttons["edit.brand.addColor"].tap()
        let well = app.descendants(matching: .any)["edit.brand.color.0"]
        XCTAssertTrue(well.exists(within: 3))
        print("PROBE well", well.elementType.rawValue, well.frame, well.isHittable, well.value ?? "nil")
        well.tap()
        Thread.sleep(forTimeInterval: 3)
        EditorApp.capture(app, "probe-after-well-tap")
        print("PROBE grid", app.buttons["Grid"].exists, app.otherElements["Grid"].exists, app.segmentedControls.count)
    }
}
