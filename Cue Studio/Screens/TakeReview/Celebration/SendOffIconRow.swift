//
//  SendOffIconRow.swift
//  Cue Studio
//

import SwiftUI

/// The milestone's icon, offered inside the send-off (D4, owner 09/11/2026: one celebration, no screen after it): the icon, "Aurora icon unlocked",
/// how many videos opened it, and **Use it** (an icon past the first comes with Pro: **Go Pro**). Leaving it there keeps the current icon; once
/// chosen it says "In use".
struct SendOffIconRow: View {
    let icon: AppIconChoice
    let milestone: Int
    let isInUse: Bool
    /// Free (Aurora) or the creator has Pro.
    let isAvailable: Bool
    let onUse: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        HStack(spacing: 12) {
            AppIconArt(icon: icon, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(icon.title) icon unlocked")
                    .cueFont(15, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .cueFont(13)
                    .foregroundStyle(Palette.ink2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("sendoff.icon.title")
            action
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sendoff.icon")
    }

    @ViewBuilder
    private var action: some View {
        if isInUse {
            Label("In use", systemImage: "checkmark")
                .cueFont(14, weight: .semibold)
                .foregroundStyle(Palette.successText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("sendoff.icon.inUse")
        } else {
            Button(action: onUse) { Text(isAvailable ? "Use it" : "Go Pro") }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityLabel(Text(isAvailable ? String(localized: "Use \(icon.title)") : String(localized: "Get \(icon.title) with Pro")))
                .accessibilityIdentifier("sendoff.icon.use")
        }
    }

    /// "Your first video shared", "10 videos shared".
    private var detail: String {
        milestone == 1 ? String(localized: "Your first video shared") : String(localized: "\(milestone) videos shared")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        SendOffIconRow(icon: .aurora, milestone: 1, isInUse: false, isAvailable: true, onUse: {})
        SendOffIconRow(icon: .firstLight, milestone: 10, isInUse: false, isAvailable: false, onUse: {})
        SendOffIconRow(icon: .aurora, milestone: 1, isInUse: true, isAvailable: true, onUse: {})
    }
    .padding()
    .background(Palette.bg)
}
#endif
