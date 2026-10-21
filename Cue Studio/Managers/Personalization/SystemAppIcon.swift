//
//  SystemAppIcon.swift
//  Cue Studio
//

import UIKit

/// The system's alternate icons. The system shows its own "You have changed the icon" alert.
@MainActor
final class SystemAppIcon: AppIconSwitching {
    var current: AppIconChoice { AppIconChoice(alternateName: UIApplication.shared.alternateIconName) }

    func set(_ icon: AppIconChoice) async throws {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        try await UIApplication.shared.setAlternateIconName(icon.alternateName)
    }
}
