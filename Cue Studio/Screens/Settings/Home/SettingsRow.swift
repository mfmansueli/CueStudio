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
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(title).foregroundStyle(Palette.ink)
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
