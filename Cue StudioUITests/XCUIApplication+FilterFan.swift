//
//  XCUIApplication+FilterFan.swift
//  Cue StudioUITests
//

import XCTest

/// The folding filter rows of Scripts and Takes (`FilterFan`): folded, only the chosen chip is there, so a test opens the row before it
/// taps another.
extension XCUIApplication {
    /// Taps the filter chip `identifier` (`scripts.filter.reels`, `takes.platform.youtube`), opening its row first when it is folded.
    func pickFilter(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let chip = buttons[identifier]
        if !chip.exists(within: 2) {
            let prefix = identifier.hasPrefix("takes.") ? "takes.platform." : "scripts.filter."
            let chosen = buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
            XCTAssertTrue(chosen.exists(within: 10), "No filter row", file: file, line: line)
            chosen.tap()
        }
        XCTAssertTrue(chip.exists(within: 5), "No chip \(identifier) in the open row", file: file, line: line)
        chip.waitUntilStill()
        chip.tap()
    }
}
