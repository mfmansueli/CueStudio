//
//  ScriptPageTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Back, the platform ("● TikTok", opens Create for) and •••. The page has no Draft | Shaped switch (v29) and no Record button up
/// here: the one Record is at the bottom.
struct ScriptPageTopBar<MenuContent: View>: View {
    let platform: Platform
    let onBack: () -> Void
    let onPlatform: () -> Void
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.accText)
                    .frame(width: 34, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Back"))
            .accessibilityIdentifier("page.backButton")
            Button(action: onPlatform) {
                HStack(spacing: 6) {
                    PlatformDot(color: platform.tint)
                    Text(platform.label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 9)
                .frame(height: 32)
                .background(Palette.overlayFill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Create for"))
            .accessibilityValue(Text(platform.label))
            .accessibilityIdentifier("page.platformChip")
            Spacer(minLength: 0)
            Menu(content: menu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Palette.editorBarButton, in: Circle())
                    .frame(width: 44, height: Metrics.hitTarget)
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text("More"))
            .accessibilityIdentifier("page.menuButton")
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        // Navigation chrome: it stays at the default size, or the page grows wider than the screen.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}
