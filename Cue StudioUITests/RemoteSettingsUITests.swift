//
//  RemoteSettingsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Settings › Remote (owner's redesign, 21/10/2026): with no remote the page invites to connect; Connect a device shows the code a
/// character to a tile and waits; a remote connecting (the demo transport's iPad, `-uiTestRemoteConnects`) shows its name and
/// Disconnect, which brings the invitation back. `CUE_SCREENSHOT_DIR` keeps a picture of each stage.
@MainActor
final class RemoteSettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openRemote(_ app: XCUIApplication) {
        app.cueTabBar.buttons["Settings"].tap()
        let row = app.descendants(matching: .any)["settings.remote"].firstMatch
        XCTAssertTrue(row.exists(within: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["remote.statusHero"].exists(within: 5))
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        sleep(2)
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    /// Without another device the teleprompter keeps waiting with its code, and Cancel brings the invitation back.
    func testConnectShowsTheCodeAndCancelComesBack() throws {
        let app = CueApp.launch(seeded: true)
        openRemote(app)
        let connect = app.buttons["remote.connectButton"]
        XCTAssertTrue(connect.exists(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.enterCode"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["remote.capabilities"].exists)
        try capture(app, "remote_1_apart")
        connect.tap()
        let code = app.descendants(matching: .any)["remote.code"].firstMatch
        XCTAssertTrue(code.exists(within: 5))
        XCTAssertTrue(code.label.hasPrefix("Code "), code.label)
        XCTAssertTrue(app.descendants(matching: .any)["remote.status"].exists)
        try capture(app, "remote_2_pairing")
        app.buttons["remote.cancelButton"].tap()
        XCTAssertTrue(connect.exists(within: 5))
    }

    /// A remote connects: its name, the capabilities lit, Disconnect; and let go, the invitation is back.
    func testARemoteConnectsThenDisconnects() throws {
        let app = CueApp.launch(seeded: true, remoteConnects: true)
        openRemote(app)
        app.buttons["remote.connectButton"].tap()
        let connected = app.descendants(matching: .any)["remote.connected"].firstMatch
        XCTAssertTrue(connected.exists(within: 10))
        XCTAssertTrue(connected.label.contains("iPad"), connected.label)
        try capture(app, "remote_3_linked")
        let disconnect = app.buttons["remote.disconnectButton"]
        XCTAssertTrue(disconnect.exists)
        disconnect.tap()
        XCTAssertTrue(app.buttons["remote.connectButton"].exists(within: 5))
    }
}
