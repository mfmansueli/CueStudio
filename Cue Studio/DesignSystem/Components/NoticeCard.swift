//
//  NoticeCard.swift
//  Cue Studio
//

import SwiftUI

/// A notice that stays where it happened until it is dealt with (04 · Componentes §3): something is off or didn't work, and the way out.
/// One form for all of them (a permission that is off, an export that failed): the orange "!" disc of a toast's problem, a title, one line
/// and the way out, on `surface` with a 20 pt corner; ✕ when it can be put away. Measured in `PaletteContrastTests.aNoticeCardReads`.
struct NoticeCard: View {
    let title: String
    let line: String
    var systemImage = "exclamationmark"
    let actionTitle: String
    var actionIdentifier: String?
    let onAction: () -> Void
    var onClose: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .cueFont(15, weight: .heavy)
                .foregroundStyle(Palette.Toast.glyph)
                .frame(width: 30, height: 30)
                .background(Palette.Toast.problem, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Text(line)
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(actionTitle, action: onAction)
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier(actionIdentifier ?? "")
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.fixed(13, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, onClose == nil ? 14 : 4)
        .padding(.vertical, 10)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.noticeRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.noticeRadius, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        NoticeCard(title: "Photos is off for Cue", line: "Allow it to save your video.", actionTitle: "Open Settings", onAction: {}, onClose: {})
        NoticeCard(title: "The microphone is off for Cue", line: "Allow it to record your voice.", actionTitle: "Open Settings", onAction: {})
        NoticeCard(title: "Couldn’t export", line: "Nothing was counted, and your take is safe.", actionTitle: "Try again", onAction: {}, onClose: {})
    }
    .padding()
    .background(Palette.bg)
}
#endif
