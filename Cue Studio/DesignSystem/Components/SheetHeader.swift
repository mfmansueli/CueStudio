//
//  SheetHeader.swift
//  Cue Studio
//

import SwiftUI

/// Title and optional subtitle for sheets. The close button is the system's (`cueSheetChrome()`).
struct SheetHeader: View {
    var title: String
    var subtitle: String?
    /// "Cancel" at the trailing edge: the sheet's way to leave on purpose, its work thrown away (a swipe down keeps a draft where
    /// the sheet keeps one).
    var onCancel: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .cueFont(.title2, weight: .bold)
                    .foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .cueFont(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onCancel {
                Button("Cancel", action: onCancel)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sheet.cancel")
            }
        }
    }
}

#if DEBUG
#Preview {
    SheetHeader(title: "Where will this go?", subtitle: "Cue sets the frame, quality and length goals.")
        .padding()
        .background(Palette.surface)
}
#endif
