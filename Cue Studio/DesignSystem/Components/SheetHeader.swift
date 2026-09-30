//
//  SheetHeader.swift
//  Cue Studio
//

import SwiftUI

/// Title, optional subtitle and a close button for custom sheets.
struct SheetHeader: View {
    var title: String
    var subtitle: String?
    var onClose: (() -> Void)?

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
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                }
                .buttonStyle(.cueIcon(.surface, diameter: 32))
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("sheet.closeButton")
            }
        }
    }
}

#if DEBUG
#Preview {
    SheetHeader(title: "Where will this go?", subtitle: "Cue sets the frame, quality and length goals.", onClose: {})
        .padding()
        .background(Palette.surface)
}
#endif
