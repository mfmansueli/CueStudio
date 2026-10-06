//
//  UniverseInfoCard.swift
//  Cue Studio
//

import SwiftUI

/// The card under the map (9.2): a 64 pt app-icon picture, a yellow mono eyebrow, a title, a line and a bar. It is the next milestone ("NEXT MILESTONE ·
/// 23 / 25"), the year of a sealed universe ("2025 · YOUR YEAR") or the first star ("FIRST STAR · 0 / 1").
struct UniverseInfoCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let progress: Double
    var icon: AppIconChoice?
    var identifier = "universe.card"

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        HStack(spacing: 14) {
            if let name = icon?.previewName {
                Image(name).resizable().scaledToFill().frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow).font(.system(size: 10.5, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.accText)
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                if !detail.isEmpty { Text(detail).font(.system(size: 13.5)).foregroundStyle(Palette.ink2) }
                ProgressView(value: min(1, max(0, progress))).tint(Palette.acc).padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
