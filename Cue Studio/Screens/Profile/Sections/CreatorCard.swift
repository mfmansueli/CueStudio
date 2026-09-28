//
//  CreatorCard.swift
//  Cue Studio
//

import SwiftUI

/// Avatar, name, handle and plan badge.
struct CreatorCard: View {
    let profile: CreatorProfile
    let isPro: Bool
    /// Signed in with Apple: shown after the handle.
    var isSignedIn = false

    var body: some View {
        HStack(spacing: 14) {
            Text(profile.initials)
                .font(.title3.bold())
                .foregroundStyle(Palette.accInk)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(colors: [Palette.acc, Palette.warn], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
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

    /// "@mayamakes · Signed in with Apple"
    private var subtitle: String {
        let handle = profile.handle.isEmpty ? nil : "@\(profile.handle)"
        let apple = isSignedIn ? String(localized: "Signed in with Apple") : nil
        let parts = [handle, apple].compactMap { $0 }
        return parts.isEmpty ? String(localized: "Tap to add your name and handle") : parts.joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    List { CreatorCard(profile: CreatorProfile(name: "Maya Reyes", handle: "mayamakes"), isPro: false) }
}
#endif
