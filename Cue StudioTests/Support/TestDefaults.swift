//
//  TestDefaults.swift
//  Cue StudioTests
//

import Foundation

/// A throwaway UserDefaults suite per test, so tests never share or leak state.
struct TestDefaults {
    let suiteName = "studio.cue.tests.\(UUID().uuidString)"

    var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}
