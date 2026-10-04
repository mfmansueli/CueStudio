//
//  TakeStage+Style.swift
//  Cue Studio
//

import SwiftUI

/// The color of each stage: yellow asks for a decision, white is work in progress, green is done and
/// waiting to post, gray is finished. Color is never the only sign: every stage also has its word.
extension TakeStage {
    /// On the app's own surfaces (they follow the appearance).
    var tint: Color {
        switch self {
        case .pick: Palette.accText
        case .edit: Palette.ink
        case .ready: Palette.successText
        case .shared: Palette.ink2
        }
    }

    /// On the dark pill over a poster or the dark review screen.
    var pillTint: Color {
        switch self {
        case .pick: Palette.acc
        case .edit: .white
        case .ready: Palette.success
        case .shared: Color(hex: 0xE1E4F5, opacity: 0.7)
        }
    }

    /// The pill's ring.
    var pillRing: Color {
        switch self {
        case .pick: Palette.acc.opacity(0.5)
        case .edit: Color.white.opacity(0.35)
        case .ready: Palette.success.opacity(0.45)
        case .shared: Color(hex: 0xE1E4F5, opacity: 0.22)
        }
    }
}
