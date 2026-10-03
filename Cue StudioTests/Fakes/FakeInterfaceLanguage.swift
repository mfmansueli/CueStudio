//
//  FakeInterfaceLanguage.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Records what the interface was switched to, without touching the app's bundle or the system.
@MainActor
final class FakeInterfaceLanguage: InterfaceLanguageApplying {
    var systemAppLanguage: String?
    private(set) var applied: [String?] = []

    init(systemAppLanguage: String? = nil) {
        self.systemAppLanguage = systemAppLanguage
    }

    func apply(_ localization: String?) -> String? {
        applied.append(localization)
        systemAppLanguage = localization
        return localization ?? "en"
    }
}
