//
//  ThemeRail.swift
//  Cue Studio
//

import SwiftUI

/// A creator topic's marker (v29): a 3 pt bar in the topic's world color, 30 pt tall in a list row and 14 pt in
/// chips and legends. A topic is a bar, never a dot (a dot is a network: `PlatformDot`). Decorative: the
/// topic's name is always written beside it.
struct ThemeRail: View {
    enum Size {
        /// 3 × 30, beside a list row.
        case row
        /// 3 × 14, in chips and legends.
        case chip

        var height: CGFloat {
            switch self {
            case .row: Metrics.themeRailRowHeight
            case .chip: Metrics.themeRailChipHeight
            }
        }
    }

    var color: Color
    var size: Size = .row

    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.themeRailRadius, style: .continuous)
            .fill(color)
            .frame(width: Metrics.themeRailWidth, height: size.height)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 16) {
        ThemeRail(color: Palette.worldWarm)
        ThemeRail(color: Palette.worldMint, size: .chip)
        ThemeRail(color: Palette.worldPink, size: .chip)
        ThemeRail(color: Palette.worldSky)
    }
    .padding()
    .background(Palette.bg)
}
#endif
