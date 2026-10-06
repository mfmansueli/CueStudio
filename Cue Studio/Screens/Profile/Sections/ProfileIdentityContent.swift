//
//  ProfileIdentityContent.swift
//  Cue Studio
//

import SwiftUI

/// What the identity row looks like (and what the menu lifts): the avatar, the name, "@mayacooks · Lifestyle creator" and a chevron.
struct ProfileIdentityContent: View {
    let profile: CreatorProfile

    var body: some View {
        HStack(spacing: 14) {
            ProfileAvatar(profile: profile, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 84)
        .profileBlock()
    }

    /// "@mayacooks · Lifestyle creator"
    private var subtitle: String {
        let handle = profile.handle.isEmpty ? nil : "@\(profile.handle)"
        let parts = [handle, profile.role?.creatorLabel].compactMap { $0 }
        return parts.isEmpty ? String(localized: "Tap to add your name and username") : parts.joined(separator: " · ")
    }
}
