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
        XCTAssertTrue(row(app, "settings.recording").isHittable)
    }

    func testTechnicalNavigationStaysOnSettingsAndReturnsToItsRoot() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        // v30: every page is pushed on the Settings stack.
        row(app, "settings.recording").tap()
        XCTAssertTrue(app.navigationBars["Recording"].waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
        app.navigationBars["Recording"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        row(app, "settings.prompter").tap()
        XCTAssertTrue(app.navigationBars["Prompter"].waitForExistence(timeout: 5))
        tab(app, label: "Profile").tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Prompter"].waitForExistence(timeout: 5))
        app.navigationBars["Prompter"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.scroll(to: row(app, "settings.languageRegion"))
        row(app, "settings.languageRegion").tap()
        XCTAssertTrue(app.navigationBars["Language & Region"].waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
        app.navigationBars["Language & Region"].buttons.firstMatch.tap()
        app.scroll(to: row(app, "settings.privacy"))
        row(app, "settings.privacy").tap()
        XCTAssertTrue(app.navigationBars["Privacy & AI data"].waitForExistence(timeout: 5))
        app.navigationBars["Privacy & AI data"].buttons.firstMatch.tap()
        XCTAssertTrue(row(app, "settings.restorePurchases").waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isSelected)
    }

    /// The row the app had before v30 stays where it was, with its own confirmation, until the product owner decides.
    func testResetCreatorSetupKeepsItsRowAndAsksFirst() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let reset = app.buttons["creatorSetup.resetButton"]
        app.scroll(to: reset)
        reset.tap()
        XCTAssertTrue(app.buttons["creatorSetup.confirmResetButton"].waitForExistence(timeout: 5))
        dismissDialog(app)
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
    }

    /// Search shows the rows themselves, grouped by where they live, and says so when nothing matches.
    func testSearchFindsRowsAndSaysWhenThereAreNone() {
        let app = CueApp.launch(seeded: true)
        tab(app, label: "Settings").tap()
        let field = app.textFields["settings.searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("mirror")
        XCTAssertTrue(row(app, "settings.mirrorText").waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "settings.flipVertically").exists)
        XCTAssertFalse(row(app, "settings.recording").exists)
        app.buttons["Clear"].tap()
        field.typeText("zzzz")
        XCTAssertTrue(row(app, "settings.noResults").waitForExistence(timeout: 5))
    }

    /// A choice made on a page shows on the root's setup card and stays after leaving.
    func testChoicesMadeInRecordingShowOnTheSetupCard() {
        let app = CueApp.launch(seeded: true)
        tab(app, label: "Settings").tap()
        row(app, "settings.recording").tap()
        row(app, "settings.resolution").tap()
        app.buttons["4K"].firstMatch.tap()
        app.navigationBars["Recording"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.setup.quality"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.setup.quality"].label.contains("4K"))
    }

    /// The Prompter page's switches are the ones the prompter reads.
    func testPrompterPageHasItsRowsAndRigs() {
        let app = CueApp.launch(seeded: true)
        tab(app, label: "Settings").tap()
        row(app, "settings.prompter").tap()
        XCTAssertTrue(row(app, "settings.followVoice").waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "settings.prompterPreview").exists)
        let mirror = row(app, "settings.mirrorText")
        app.scroll(to: mirror)
        XCTAssertTrue(row(app, "settings.flipVertically").exists)
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
            XCTAssertTrue(row(app, "settings.recording").waitForExistence(timeout: 5))
            capture(app, name: "Settings · \(language)")
            // Everything stays reachable by scrolling, in every language.
            app.scroll(to: row(app, "settings.restorePurchases"))
            XCTAssertTrue(row(app, "settings.restorePurchases").isHittable)
            app.terminate()
        }
    }

    func testSettingsWithAccessibilityTextKeepsRowsReachable() {
        let app = CueApp.launch(seeded: true, appLanguage: "de", contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        assertTabs(app, labels: ["Skripte", "Takes", "Aufnehmen", "Profil", "Einstellungen"])
        tab(app, label: "Einstellungen", index: 4).tap()
        let language = row(app, "settings.languageRegion")
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 5))
        capture(app, name: "Settings · German · Accessibility XXXL")
        app.scroll(to: language)
        XCTAssertTrue(language.isHittable)
        let restore = row(app, "settings.restorePurchases")
        app.scroll(to: restore)
        XCTAssertTrue(restore.isHittable)
        capture(app, name: "Settings · German · Accessibility XXXL · Bottom")
    }

    func testFontLicensesRemainReachableFromSettings() {
        let app = CueApp.launch(seeded: true)
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let acknowledgements = row(app, "settings.acknowledgements")
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
        openPrivacy(app)
        let delete = row(app, "settings.deleteData")
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.buttons["privacy.confirmDelete"].firstMatch.waitForExistence(timeout: 5))
        dismissDialog(app)
        app.swipeDown()
        tab(app, label: "Scripts").tap()
        XCTAssertTrue(sampleScript(app).waitForExistence(timeout: 5))
    }

    func testDeleteMyDataRemovesTheScripts() {
        let app = CueApp.launch(seeded: true)
        openPrivacy(app)
        row(app, "settings.deleteData").tap()
        let confirm = app.buttons["privacy.confirmDelete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        app.swipeDown()
        tab(app, label: "Scripts").tap()
        XCTAssertTrue(app.descendants(matching: .any)["empty.promptCard"].waitForExistence(timeout: 10))
        XCTAssertFalse(sampleScript(app).exists)
    }

    /// The system answers a confirmation with a bubble that has no Cancel: a tap outside it says no.
    private func dismissDialog(_ app: XCUIApplication) {
        let cancel = app.buttons["actionSheet.cancel"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.85)).tap() }
    }

    private func openPrivacy(_ app: XCUIApplication) {
        let settings = tab(app, label: "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        app.scroll(to: row(app, "settings.privacy"))
        row(app, "settings.privacy").tap()
    }

    private func row(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func sampleScript(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '3 morning habits'")).firstMatch
    }
}
