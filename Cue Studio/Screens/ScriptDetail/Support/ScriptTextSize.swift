//
//  ScriptTextSize.swift
//  Cue Studio
//

import SwiftUI

/// How big the text is on the script page (its Aa button). It only changes the page; the prompter
/// has its own size.
nonisolated enum ScriptTextSize: Int, CaseIterable, Identifiable, Sendable {
    case small = 17
    case medium = 19
    case large = 22

    var id: Int { rawValue }

    /// Points at the default Dynamic Type size, on a board-wide iPhone.
    var points: Double { Double(rawValue) }

    /// The text size the page draws for `dynamicTypeSize`: grown as the body text grows, up to the second accessibility size (past it a
    /// line holds two or three words and editing stops working), and following the iPhone's width (`ScreenProportion`).
    @MainActor func points(for dynamicTypeSize: DynamicTypeSize) -> Double {
        InterfaceType.size(points, relativeTo: .body, for: min(dynamicTypeSize, .accessibility2), proportion: ScreenProportion.current)
    }
}
