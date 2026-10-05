//
//  SheetHeader.swift
//  Cue Studio
//

import SwiftUI

/// Title and optional subtitle for sheets. The close button is the system's (`cueSheetChrome()`).
struct SheetHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
