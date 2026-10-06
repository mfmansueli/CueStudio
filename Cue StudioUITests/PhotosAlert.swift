//
//  PhotosAlert.swift
//  Cue StudioUITests
//

import XCTest

extension XCTestCase {
    /// Waits for `element`, answering the system's Photos permission prompt (which saving a video asks for the first time) with "Allow".
    @MainActor
    func waitAllowingPhotos(for element: XCUIElement, timeout: TimeInterval = 40) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            for name in ["Allow Full Access", "Allow Access to All Photos", "Allow", "OK"] {
                let button = springboard.alerts.buttons[name]
                if button.exists { button.tap() }
            }
            usleep(400_000)
        }
        return element.exists
    }
}
