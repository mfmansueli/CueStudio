//
//  AppIconService.swift
//  Cue Studio
//

import UIKit

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
