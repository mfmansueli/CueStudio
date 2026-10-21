//
//  InMemoryAppIcon.swift
//  Cue Studio
//

import UIKit

/// Keeps the choice in memory, for tests that must not bring up the system's alert.
@MainActor
final class InMemoryAppIcon: AppIconSwitching {
    private(set) var current: AppIconChoice = .standard

    func set(_ icon: AppIconChoice) async throws {
        current = icon
    }
}
