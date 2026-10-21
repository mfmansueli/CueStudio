//
//  CreatorWorkflow.swift
//  Cue StudioUITests
//

import XCTest

/// Drives the editor the way a creator edits a short vertical video on a phone, and counts what it takes: taps (a tool, a
/// tile, a word, a point on the timeline), drags (scrubbing, swiping the toolbar to a tool off screen, swiping a sheet away)
/// and typing. Counting starts in the editor (getting there from Takes is three more taps). Each step is printed as
/// `CREATOR STEP …` and, with `TEST_RUNNER_CUE_SCREENSHOT_DIR`, saved as a picture; `report()` prints
/// `CREATOR FLOW <name> · <n> taps …` to compare with CapCut and Edits.
@MainActor
final class CreatorWorkflow {
    let app: XCUIApplication
    let name: String
    private(set) var taps = 0
    private(set) var drags = 0
    private(set) var typing = 0
    /// Waits that ran out once and were tried again (a slow Simulator, not the app).
    private(set) var retries: [String] = []
    private var stepNumber = 0

    init(_ name: String, app: XCUIApplication) {
        self.app = app
        self.name = name
    }

    // MARK: - Elements

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The editor's main tools are back: nothing picked, no panel.
    func isOnMainTools(timeout: TimeInterval = 5) -> Bool {
        waits(for: app.buttons["edit.toolbar.smart"], timeout: timeout, "the main tools")
            && app.buttons["edit.toolbar.addMedia"].exists && !app.buttons["edit.toolbar.back"].exists
    }

    /// The toast's own Undo, the one on screen (the screen under the editor has a toast host of its own).
    var toastUndo: XCUIElement? {
        app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
    }

    // MARK: - Gestures

    /// Taps `element` once it is there and on screen. XCUITest sometimes calls an element that is plainly on screen (a filter card
    /// in a sideways row) not hittable: then the tap goes to its middle, and what the tap does is checked by the caller.
    func tap(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(for: element, what), "\(what) isn't there", file: file, line: line)
        if !element.isHittable {
            // An animation still settling (a sheet, a panel): one more look.
            Thread.sleep(forTimeInterval: 1)
        }
        if element.isHittable {
            element.tap()
        } else {
            let screen = app.windows.firstMatch.frame
            capture("untouchable-\(what.filter { $0.isLetter || $0.isNumber })")
            XCTAssertTrue(screen.contains(element.frame), "\(what) is off screen (at \(element.frame))", file: file, line: line)
            print("CREATOR STEP \(name) · \(what) isn't hittable for XCUITest at \(element.frame): tapped its middle")
            retries.append("\(what) tapped by its middle")
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        taps += 1
    }

    func tap(_ coordinate: XCUICoordinate) {
        coordinate.tap()
        taps += 1
    }

    /// A toolbar tool, scrolled into reach the way a thumb does it: slow drags of the bar that stop where they end (each one
    /// counts), until the tool is clear of the edges and of the pinned Delete.
    func tool(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["edit.toolbar.\(id)"]
        XCTAssertTrue(waits(for: button, "the \(id) tool"), "No \(id) tool in the toolbar", file: file, line: line)
        let bar = element("edit.toolbar")
        for _ in 0..<6 {
            let reach = reachableBar(for: id, in: bar.frame)
            let frame = button.frame
            if frame.minX >= reach.minX, frame.maxX <= reach.maxX { break }
            // Bring the tool to the middle of what can be reached, at most a bar's width at a time.
            let distance = max(-reach.width + 40, min(reach.width - 40, reach.midX - frame.midX))
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: reach.midX - distance / 2, dy: bar.frame.midY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: distance, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
            drags += 1
        }
        tap(button, "the \(id) tool", file: file, line: line)
    }

    /// The part of the toolbar a tool can be touched in: inside the screen, right of the ‹ back and left of the pinned Delete.
    private func reachableBar(for id: String, in bar: CGRect) -> CGRect {
        let screen = app.windows.firstMatch.frame
        var reach = bar.intersection(screen)
        let back = app.buttons["edit.toolbar.back"]
        if back.exists, id != "back" { reach = reach.divided(atDistance: max(0, back.frame.maxX - reach.minX), from: .minXEdge).remainder }
        let delete = app.buttons["edit.toolbar.delete"]
        if delete.exists, id != "delete" { reach.size.width = max(0, delete.frame.minX - reach.minX) }
        return reach
    }

    /// Moves the playhead forward by dragging the timeline (`EditorApp.scrub`).
    func scrub(points: CGFloat = 300) {
        EditorApp.scrub(app, points: points)
        drags += 1
    }

    /// Drags a list up from `start` until `element` can be touched, as a thumb scrolls a panel (each drag counts).
    func scrollUp(to element: XCUIElement, from start: XCUICoordinate, file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while !(element.exists && element.isHittable), swipes < 6 {
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: 600, thenHoldForDuration: 0.2)
            swipes += 1
            drags += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "Scrolled \(swipes) times and \(element) can't be touched", file: file, line: line)
    }

    /// Scrolls the panel (dragging from its lower part) until `element`, under its fold, is on screen; nothing when it already is.
    func reveal(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(for: element, what), "\(what) isn't there", file: file, line: line)
        guard !app.windows.firstMatch.frame.contains(element.frame) else { return }
        print("CREATOR STEP \(name) · \(what) is under the fold at \(element.frame): scrolling the panel")
        scrollUp(to: element, from: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)), file: file, line: line)
    }

    /// Clears `field` and types `text` (with the keyboard already up for it).
    func replaceText(of field: XCUIElement, with text: String) {
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2) + text)
        typing += 1
    }

    /// The yellow ‹ back from a picked item's tools to the main ones.
    func backToMainTools(file: StaticString = #filePath, line: UInt = #line) {
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { tap(back, "‹ back", file: file, line: line) }
        XCTAssertTrue(isOnMainTools(), "Not back on the main tools", file: file, line: line)
    }

    // MARK: - Waiting

    /// Waits for `element`; a wait that runs out is tried once more and noted (a slow Simulator, not a missing control).
    func waits(for element: XCUIElement, timeout: TimeInterval = 5, _ what: String) -> Bool {
        if element.exists(within: timeout) { return true }
        retries.append(what)
        print("CREATOR STEP \(name) · retrying the wait for \(what)")
        return element.exists(within: timeout)
    }

    /// A toast saying `text` shows (the editor's, matched by its words).
    func toastSays(_ text: String, timeout: TimeInterval = 5) -> Bool {
        if EditorApp.toastSays(app, text, timeout: timeout) { return true }
        return app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists(within: 1)
    }

    // MARK: - Reporting

    /// Starts a step: printed with the taps so far, and saved as a picture when asked to.
    func step(_ title: String) {
        stepNumber += 1
        print("CREATOR STEP \(name) · \(stepNumber). \(title) · \(taps) taps so far")
        capture(String(format: "%02d", stepNumber))
    }

    /// The screen now, in `TEST_RUNNER_CUE_SCREENSHOT_DIR` (nothing without it).
    func capture(_ suffix: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(device)-\(name)-\(suffix).png"))
    }

    /// `CREATOR FLOW <name> · <n> taps · <d> drags · <t> typed`, on the device it ran on.
    func report() {
        capture("end")
        let retried = retries.isEmpty ? "" : " · retried: \(retries.joined(separator: ", "))"
        print("CREATOR FLOW \(name) · \(taps) taps · \(drags) drags · \(typing) typed · \(UIDevice.current.name)\(retried)")
    }
}
