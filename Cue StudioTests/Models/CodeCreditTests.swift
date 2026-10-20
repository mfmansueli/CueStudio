//
//  CodeCreditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The notice each adapted work needs ships with the app: the MIT licenses and the face mesh's Apache one, with what was changed.
@Suite("Code credits")
struct CodeCreditTests {
    @Test func everyCreditShipsItsLicense() {
        for credit in CodeCredit.all {
            let text = credit.licenseText
            #expect(text.contains("Permission is hereby granted") || text.contains("Apache License"), "\(credit.name)")
            #expect(text.contains(credit.copyright), "\(credit.name)")
        }
    }

    @Test func theFaceMeshsNoticeSaysWhatChanged() throws {
        let credit = try #require(CodeCredit.all.first { $0.licenseFile == "mediapipe-Apache-2.0" })
        // Apache 2.0, section 4: the license travels with the work, and changed files say they were changed.
        #expect(credit.licenseText.contains("Version 2.0, January 2004"))
        #expect(credit.licenseText.contains("Changed for Cue Studio"))
    }
}
