//
//  AppIconService.swift
//  Cue Studio
//

import UIKit

/// Switches the app's Home Screen icon.
@MainActor
protocol AppIconSwitching: AnyObject {
    var current: AppIconChoice { get }
    func set(_ icon: AppIconChoice) async throws
}

/// The system's alternate icons. The system shows its own "You have changed the icon" alert.
@MainActor
final class SystemAppIcon: AppIconSwitching {
    var current: AppIconChoice { AppIconChoice(alternateName: UIApplication.shared.alternateIconName) }

    func set(_ icon: AppIconChoice) async throws {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        try await UIApplication.shared.setAlternateIconName(icon.alternateName)
    }
}

/// Keeps the choice in memory, for tests that must not bring up the system's alert.
@MainActor
final class InMemoryAppIcon: AppIconSwitching {
    private(set) var current: AppIconChoice = .standard

    func set(_ icon: AppIconChoice) async throws {
        current = icon
    }
}

/// The creator's icon choice, for Settings › Personalize and the milestone screen.
@MainActor
@Observable
final class AppIconService {
    private(set) var current: AppIconChoice
    private let switcher: AppIconSwitching

    init(switcher: AppIconSwitching) {
        self.switcher = switcher
        current = switcher.current
    }

    /// Returns whether the icon was changed.
    @discardableResult
    func choose(_ icon: AppIconChoice) async -> Bool {
        guard icon != current else { return true }
        do {
            try await switcher.set(icon)
            current = switcher.current
            return true
        } catch {
            return false
        }
    }
}
