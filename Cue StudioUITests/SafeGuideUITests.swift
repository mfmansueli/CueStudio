//
//  SafeGuideUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The safe zone guide in the editor (owner, decision B, 07/11/2026): Aspect ratio › Safe zones turns it on, on the script's platform
/// (TikTok for "3 morning habits"); the label on the preview names the app and says it is approximate; the app switches in the
/// panel or from the label's menu, one undo step; the label's menu hides it. Every control by VoiceOver's label too.
@MainActor
final class SafeGuideUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheGuideTurnsOnInAspectRatioSwitchesAppsAndHidesFromThePreview() {
        let app = EditorApp.open()
        let badge = app.descendants(matching: .any)["edit.safeGuide.badge"]
        XCTAssertFalse(badge.exists, "The guide starts hidden")

        EditorApp.tapTool(app, "format")
        let toggle = app.descendants(matching: .any)["edit.crop.safeGuide"]
        XCTAssertTrue(toggle.exists(within: 5))
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.label, "Safe zones")
        XCTAssertEqual(toggle.value as? String, "Off")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "On")

        // On the script's platform, said on the preview as approximate.
        let tiktok = app.buttons["edit.crop.safeGuideApp.tiktok"]
        XCTAssertTrue(tiktok.exists(within: 5))
        XCTAssertTrue(tiktok.isSelected, "The guide opens on the script's platform")
        XCTAssertTrue(app.descendants(matching: .any)["edit.crop.safeGuideNote"].exists)
        XCTAssertTrue(badge.exists(within: 5))
        XCTAssertTrue(badge.hasLabel("Safe zones: TikTok · approximate"), badge.label)

        // Another app in the panel.
        let reels = app.buttons["edit.crop.safeGuideApp.reels"]
        reveal(reels, in: app)
        reels.tap()
        XCTAssertTrue(reels.isSelected)
        XCTAssertTrue(badge.hasLabel("Safe zones: Reels · approximate"), badge.label)
        app.buttons["edit.panel.apply"].tap()

        // From the label's menu on the preview, with no panel open.
        XCTAssertTrue(badge.exists(within: 5))
        badge.tap()
        let shorts = app.buttons["Shorts"]
        XCTAssertTrue(shorts.exists(within: 5), "The label's menu lists the apps")
        shorts.tap()
        XCTAssertTrue(badge.hasLabel("Safe zones: Shorts · approximate"), badge.label)

        // The app is this video's choice, one undo step; Undo leaves the guide showing.
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(badge.hasLabel("Safe zones: Reels · approximate"), badge.label)

        // Hidden from the same menu.
        badge.tap()
        let hide = app.buttons["Hide safe zones"]
        XCTAssertTrue(hide.exists(within: 5))
        hide.tap()
        XCTAssertTrue(badge.isGone(within: 5), "Hide safe zones didn't hide the guide")
    }

    // MARK: - Helpers

    /// Scrolls the open panel up until `element` can be touched.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88))
            from.press(
                forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)),
                withVelocity: .default, thenHoldForDuration: 0.1
            )
        }
        XCTAssertTrue(element.isHittable, "\(element) can't be touched")
    }
}

private extension XCUIElement {
    /// Its label becomes `label` within a few seconds.
    func hasLabel(_ label: String) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if exists, self.label == label { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }
}
