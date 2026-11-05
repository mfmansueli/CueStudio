//
//  FreeExportBars.swift
//  Cue Studio
//

import SwiftUI

/// The free exports as small bars, the used ones lit: yellow on the last export, orange when they are gone. With the exports invites
/// earned, more than fit as bars (up to 18): then one bar, as long as what is left.
struct FreeExportBars: View {
    let left: Int
    let total: Int
    let width: CGFloat
    let height: CGFloat
    let spacing: CGFloat

    /// Beyond this many, one proportional bar.
    static let mostBars = 6

    private var lit: Color { left <= 1 ? Palette.acc : Palette.warn }

    var body: some View {
        if total <= Self.mostBars {
            HStack(spacing: spacing) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < total - left ? lit : Palette.fill)
                        .frame(width: width, height: height)
                }
            }
        } else {
            let length = (width + spacing) * CGFloat(UsagePolicy.freeExports) - spacing
            Capsule()
                .fill(Palette.fill)
                .frame(width: length, height: height)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(lit)
                        .frame(width: length * CGFloat(total - left) / CGFloat(max(1, total)), height: height)
                }
        }
    }
}
