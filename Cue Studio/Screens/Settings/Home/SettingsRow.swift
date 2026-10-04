//
//  SettingsRow.swift
//  Cue Studio
//

import SwiftUI

/// A row of "General" and "Purchases & About": an icon tile, the name, what is set and a chevron.
struct SettingsRow: View {
    let systemImage: String
    var tint: Color = Palette.infoText
    let title: String
    var value: String?
    /// A second line under the title.
    var detail: String?
    /// A small tag after the title ("NEW").
    var badge: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title).foregroundStyle(Palette.ink)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Palette.accText)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(Palette.accSoft, in: Capsule())
                    }
                }
                if let detail { Text(detail).font(.footnote).foregroundStyle(Palette.ink2).lineLimit(2) }
            }
            Spacer(minLength: 8)
            if let value {
                Text(verbatim: value).foregroundStyle(Palette.ink2).lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
