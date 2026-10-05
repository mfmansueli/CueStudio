//
//  SettingsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The five tabs, technical navigation and the boundary between Profile and Settings.
@MainActor
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFiveTabsKeepTheirOrderAndRecordKeepsSettingsSelected() {
        let app = CueApp.launch(seeded: true)
        assertTabs(app, labels: ["Scripts", "Takes", "Record", "Profile", "Settings"])
        tab(app, label: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture(app, name: "Settings · English")
        tab(app, label: "Record").tap()
        XCTAssertTrue(app.buttons["startRecording.skip"].waitForExistence(timeout: 5))
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(tab(app, label: "Settings").isSelected)
        XCTAssertTrue(app.buttons["settings.recordingTile"].isHittable)
    }

    func testTechnicalNavigationStaysOnSettingsAndReturnsToItsRoot() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        // Recording and Language & Region are sheets over Settings (v29 · L14); Prompter is still pushed.
        app.buttons["settings.recordingTile"].tap()
        XCTAssertTrue(app.navigationBars["Recording"].waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
        app.buttons["settings.sheetDone"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["settings.prompterTile"].tap()
        XCTAssertTrue(app.navigationBars["Prompter"].waitForExistence(timeout: 5))
        tab(app, label: "Profile").tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Prompter"].waitForExistence(timeout: 5))
        app.navigationBars["Prompter"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["settings.languageRegionButton"].tap()
        XCTAssertTrue(app.navigationBars["Language & Region"].waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
        app.buttons["settings.sheetDone"].tap()
        XCTAssertTrue(app.buttons["settings.privacyButton"].waitForExistence(timeout: 5))
        app.buttons["settings.privacyButton"].tap()
        XCTAssertTrue(app.navigationBars["Privacy & AI data"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["settings.restorePurchasesButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
    }

    /// The creative preferences are in the profile sheet (the identity row opens it), not in Settings, and they survive tab changes.
    func testCreativePreferencesStayInProfileAndSurviveTabChanges() {
        let app = CueApp.launch(seeded: true)
        let profile = tab(app, label: "Profile")
        XCTAssertTrue(profile.waitForExistence(timeout: 15))
        profile.tap()
        let identity = app.descendants(matching: .any)["profile.creatorCard"].firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        identity.tap()
        let goals = app.switches["profile.monetizationGoalsToggle"]
        app.scroll(to: goals)
        XCTAssertTrue(app.buttons["profile.defaultPlatformPicker"].exists)
        goals.tap()
        let saved = goals.value as? String
        capture(app, name: "Profile · Creator preferences")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["settings.recordingTile"].exists)
        XCTAssertFalse(app.buttons["settings.languageRegionButton"].exists)
        tab(app, label: "Settings").tap()
        XCTAssertTrue(app.buttons["settings.restorePurchasesButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["profile.monetizationGoalsToggle"].exists)
        profile.tap()
        identity.tap()
        app.scroll(to: goals)
        XCTAssertEqual(goals.value as? String, saved)
    }

    func testLongTranslationsKeepAllFiveTabsVisible() {
        let locales = [
            ("de", ["Skripte", "Takes", "Aufnehmen", "Profil", "Einstellungen"]),
            ("pt-BR", ["Roteiros", "Takes", "Gravar", "Perfil", "Ajustes"]),
            ("it", ["Copioni", "Riprese", "Registra", "Profilo", "Impostazioni"]),
        ]
        for (language, labels) in locales {
            let app = CueApp.launch(seeded: true, appLanguage: language)
            assertTabs(app, labels: labels)
            tab(app, label: labels[4], index: 4).tap()
            XCTAssertTrue(app.buttons["settings.recordingTile"].waitForExistence(timeout: 5))
            capture(app, name: "Settings · \(language)")
            // Everything stays reachable by scrolling, in every language.
            app.scroll(to: app.buttons["settings.restorePurchasesButton"])
            XCTAssertTrue(app.buttons["settings.restorePurchasesButton"].isHittable)
            app.terminate()
        }
    }

    func testSettingsWithAccessibilityTextKeepsRowsReachable() {
        let app = CueApp.launch(seeded: true, appLanguage: "de", contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        assertTabs(app, labels: ["Skripte", "Takes", "Aufnehmen", "Profil", "Einstellungen"])
        tab(app, label: "Einstellungen", index: 4).tap()
        let language = app.buttons["settings.languageRegionButton"]
        XCTAssertTrue(language.waitForExistence(timeout: 5))
        capture(app, name: "Settings · German · Accessibility XXXL")
        app.scroll(to: language)
        XCTAssertTrue(language.isHittable)
        let restore = app.buttons["settings.restorePurchasesButton"]
        app.scroll(to: restore)
        XCTAssertTrue(restore.isHittable)
        capture(app, name: "Settings · German · Accessibility XXXL · Bottom")
    }

    func testFontLicensesRemainReachableFromSettings() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let acknowledgements = app.buttons["settings.acknowledgementsButton"]
        app.scroll(to: acknowledgements)
        acknowledgements.tap()
        XCTAssertTrue(app.navigationBars["Acknowledgements"].waitForExistence(timeout: 5))
        let font = app.buttons.matching(identifier: "acknowledgements.font").firstMatch
        XCTAssertTrue(font.waitForExistence(timeout: 5))
        font.tap()
        XCTAssertTrue(app.descendants(matching: .any)["acknowledgements.license"].waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
    }

    // MARK: - Helpers

    private func assertTabs(_ app: XCUIApplication, labels: [String]) {
        let first = tab(app, label: labels[0], index: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        let hasBottomBar = app.cueTabBar.exists
        if hasBottomBar { XCTAssertEqual(app.cueTabBar.buttons.count, 5) }
        var previousCenter: CGFloat?
        for (index, label) in labels.enumerated() {
            let item = tab(app, label: label, index: index)
            XCTAssertEqual(item.label, label)
            XCTAssertTrue(item.isHittable)
            XCTAssertGreaterThanOrEqual(item.frame.width, 44)
            // iPad uses the existing native top bar with 36-point controls.
            XCTAssertGreaterThanOrEqual(item.frame.height, hasBottomBar ? 44 : 36)
            XCTAssertTrue(app.frame.contains(item.frame))
            if let previousCenter {
                // Liquid Glass expands accessibility frames around each item.
                XCTAssertGreaterThanOrEqual(item.frame.midX - previousCenter, 44)
            }
            previousCenter = item.frame.midX
        }
    }

    private func tab(_ app: XCUIApplication, label: String, index: Int? = nil) -> XCUIElement {
        if app.cueTabBar.exists { return app.cueTabBar.buttons[label] }
        // On iPad the native top bar exposes nested Buttons instead of a TabBar.
        let labels = ["Scripts", "Takes", "Record", "Profile", "Settings"]
        let symbols = ["doc.text", "film.stack", "", "person.crop.circle", "gearshape"]
        let symbol = symbols[index ?? labels.firstIndex(of: label) ?? 0]
        return app.buttons.matching(NSPredicate(format: "label == %@ AND identifier == %@", label, symbol)).firstMatch
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// F8 · Privacy & AI data: "Delete my Cue data" asks first (irreversible), and cancelling changes nothing.
    func testDeleteMyDataAsksForConfirmationAndCancelKeepsEverything() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        app.buttons["settings.privacyButton"].tap()
        let delete = app.buttons["privacy.deleteButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.alerts["Delete all your Cue data?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        app.buttons["Done"].tap()
        tab(app, label: "Scripts").tap()
        XCTAssertTrue(sampleScript(app).waitForExistence(timeout: 5))
    }

    func testDeleteMyDataRemovesTheScripts() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        app.buttons["settings.privacyButton"].tap()
        app.buttons["privacy.deleteButton"].tap()
        app.alerts.firstMatch.buttons["privacy.confirmDelete"].firstMatch.tap()
        // The sheet closes by itself and the library is empty: the first-visit screen is back.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["privacy.deleteButton"])
        waitForExpectations(timeout: 10)
        tab(app, label: "Scripts").tap()
        XCTAssertTrue(app.descendants(matching: .any)["empty.promptCard"].waitForExistence(timeout: 10))
        XCTAssertFalse(sampleScript(app).exists)
    }

    private func sampleScript(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '3 morning habits'")).firstMatch
    }
}
