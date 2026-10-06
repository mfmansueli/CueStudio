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
        case .shared: Palette.flightInk.opacity(0.7)
        }
    }

    /// 6.2: the colour a stage has on its pill over a poster and on the pipeline's nodes (yellow asks, cyan works, green waits, lilac is done).
    var boardTint: Color {
        switch self {
        case .pick: Palette.acc
        case .edit: Palette.info
        case .ready: Palette.success
        case .shared: Palette.starLilac
        }
    }

    /// The ring round a video's card in the grid.
    var cardRing: Color {
        switch self {
        case .pick: Palette.acc.opacity(0.55)
        case .edit: Palette.info.opacity(0.45)
        case .ready: Palette.success.opacity(0.5)
        case .shared: Palette.flightLilac.opacity(0.4)
        }
    }
}
