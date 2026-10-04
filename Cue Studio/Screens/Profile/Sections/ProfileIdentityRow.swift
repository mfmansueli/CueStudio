//
//  ProfileIdentityRow.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · who this is: the initial, the name, "@handle · kind of creator" and the plan pill, in one row. Opens the profile sheet.
struct ProfileIdentityRow: View {
    let profile: CreatorProfile
    let isPro: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(profile.initials)
                .font(.title3.bold())
                .foregroundStyle(Palette.accInk)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(colors: [Palette.acc, Palette.warn], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(isPro ? "PRO" : "FREE")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(isPro ? Palette.accInk : Palette.ink)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(isPro ? Palette.acc : Palette.fill, in: Capsule())
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 76)
        .profileBlock()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Edits your name and handle"))
    }

    /// "@mayacooks · Lifestyle creator"
    private var subtitle: String {
        let handle = profile.handle.isEmpty ? nil : "@\(profile.handle)"
        let parts = [handle, profile.role?.label].compactMap { $0 }
        return parts.isEmpty ? String(localized: "Tap to add your name and handle") : parts.joined(separator: " · ")
    }
}

extension View {
    /// A Profile block: `surface`, 22 pt radius and the faint violet edge.
    func profileBlock() -> some View {
        profileBlock(glow: Color.clear)
    }

    /// The same block with a soft light behind its content (a radial gradient from one corner).
    func profileBlock(glow: some ShapeStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.profileBlockRadius, style: .continuous)
        return background {
            ZStack {
                Palette.surface
                Rectangle().fill(glow)
            }
            .clipShape(shape)
        }
        .overlay(shape.strokeBorder(Palette.glassBorder.opacity(0.7), lineWidth: 0.5))
    }
}

/// The small mono label over a Profile block ("YOUR UNIVERSE", "MY CUE VOICE", "PLAN").
struct ProfileBlockLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Palette.inkHint)
            .padding(EdgeInsets(top: 16, leading: 12, bottom: 6, trailing: 4))
            .accessibilityAddTraits(.isHeader)
    }
}
