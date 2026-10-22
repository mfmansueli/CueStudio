//
//  CodeCreditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The notice each adapted work needs ships with the app: its MIT license.
@Suite("Code credits")
struct CodeCreditTests {
    @Test func everyCreditShipsItsLicense() {
        for credit in CodeCredit.all {
            let text = credit.licenseText
            #expect(text.contains("Permission is hereby granted"), "\(credit.name)")
            #expect(text.contains(credit.copyright), "\(credit.name)")
        }
    }
}
