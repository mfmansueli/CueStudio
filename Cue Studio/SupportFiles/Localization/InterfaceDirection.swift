//
//  InterfaceDirection.swift
//  Cue Studio
//

import UIKit

/// The interface language's direction where UIKit reads it: every window's trait. SwiftUI's own environment (`RootView`) only
/// reaches the screens drawn in the window's hierarchy; a sheet, a full-screen cover and the content of a navigation stack are
/// screens of their own that take their direction from UIKit, so without the trait they stayed in the system language's
/// (Arabic chosen in Cue on an iPhone in English laid out its editor panels left to right).
@MainActor
enum InterfaceDirection {
    static func apply(rightToLeft: Bool) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.traitOverrides.layoutDirection = rightToLeft ? .rightToLeft : .leftToRight
            }
        }
    }
}
