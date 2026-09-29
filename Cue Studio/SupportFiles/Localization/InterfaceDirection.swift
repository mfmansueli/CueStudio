//
//  InterfaceDirection.swift
//  Cue Studio
//

import UIKit

/// Mirrors UIKit's own views (tab bar, navigation bars) when the interface language changes
/// direction without a relaunch. SwiftUI mirrors from the environment (`RootView`); after the next
/// launch the system lays everything out in the language's direction on its own.
@MainActor
enum InterfaceDirection {
    /// The direction the system started the app in, from the language it picked at launch.
    private static let launchIsRightToLeft = Locale.Language(
        identifier: Bundle.main.preferredLocalizations.first ?? "en"
    ).characterDirection == .rightToLeft

    static func apply(rightToLeft: Bool) {
        let attribute: UISemanticContentAttribute = switch (rightToLeft, launchIsRightToLeft) {
        case (true, false): .forceRightToLeft
        case (false, true): .forceLeftToRight
        default: .unspecified
        }
        // Only UIKit's bars: forcing every view (SwiftUI's hosting views too) fights SwiftUI's
        // own mirroring and leaves the screen blank.
        UINavigationBar.appearance().semanticContentAttribute = attribute
        UITabBar.appearance().semanticContentAttribute = attribute
        UIToolbar.appearance().semanticContentAttribute = attribute
        UISearchBar.appearance().semanticContentAttribute = attribute
    }
}
