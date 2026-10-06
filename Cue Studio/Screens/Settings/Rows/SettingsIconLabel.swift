//
//  SettingsIconLabel.swift
//  Cue Studio
//

import SwiftUI

/// The label of a row on the Settings root: a 30 pt icon tile (radius 8), the title, what is set, and a small tag ("NEW").
struct SettingsIconLabel: View {
    let systemImage: String
    var tint: Color
    var glyph: Color = .white
    let title: String
    var titleColor: Color = Palette.ink
    var value: String?
    var badge: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(title).foregroundStyle(titleColor)
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.accInk)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Palette.acc, in: Capsule())
            }
            Spacer(minLength: 8)
            if let value {
                Text(verbatim: value).foregroundStyle(Palette.ink2).lineLimit(1)
            }
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }
}
