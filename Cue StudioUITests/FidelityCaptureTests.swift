//
//  FidelityCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the app's screens named after the prototype's board IDs (`3.2`, `9.1`…), for comparing them with the boards in
/// `design/cue-v29/prototype/cue-universe-v28/boards`. Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`; nothing is asserted
/// beyond the screen opening.
@MainActor
final class FidelityCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private var folder: URL? {
        ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func requireFolder() throws -> URL {
        guard let folder else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func shot(_ app: XCUIApplication, _ id: String, wait: UInt32 = 1) throws {
        let folder = try requireFolder()
        sleep(wait)
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(id).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    // MARK: - 3 · Scripts

    func test3_Scripts() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.cueTabBar.buttons["Scripts"].waitForExistence(timeout: 15))
        try shot(app, "3.2")
        app.buttons["scripts.newButton"].tap()
        try shot(app, "3.5")
    }

    func test3_1_ScriptsFirstVisit() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.promptCard").waitForExistence(timeout: 15))
        try shot(app, "3.1")
    }

    // MARK: - 9 · Profile

    func test9_Profile() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(element(app, "profile.creatorCard").waitForExistence(timeout: 5))
        try shot(app, "9.1")
    }
}
