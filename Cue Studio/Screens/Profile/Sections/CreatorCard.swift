//
//  CreatorCard.swift
//  Cue Studio
//

import SwiftUI

/// Avatar, name, handle and plan badge.
struct CreatorCard: View {
    let profile: CreatorProfile
    let isPro: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(profile.initials)
                .font(.title3.bold())
                .foregroundStyle(Palette.accInk)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(colors: [Palette.acc, Color(hex: 0xFF9F0A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text(profile.handle.isEmpty ? String(localized: "Tap to add your name and handle") : "@\(profile.handle)")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(isPro ? "PRO" : "FREE")
                .font(.caption.weight(.bold))
                .kerning(0.5)
                .foregroundStyle(isPro ? Palette.accInk : Palette.ink.opacity(0.8))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(isPro ? Palette.acc : Palette.surface2, in: Capsule())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Edits your name and handle"))
    }
}

#if DEBUG
#Preview {
    List { CreatorCard(profile: CreatorProfile(name: "Maya Reyes", handle: "mayamakes"), isPro: false) }
}
#endif
