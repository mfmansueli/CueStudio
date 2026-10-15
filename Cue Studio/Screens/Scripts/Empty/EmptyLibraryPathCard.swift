//
//  EmptyLibraryPathCard.swift
//  Cue Studio
//

import SwiftUI

/// One way in on the empty Scripts ("Write it yourself", "Import a script"): a softly rounded dark card with a hairline,
/// the icon in a small grey square on the left, the title and a line under it, and a disclosure chevron. The whole card is the button.
/// At the biggest text sizes the icon goes above the words, so the words keep the width.
struct EmptyLibraryPathCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private static let shape = RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)

    var body: some View {
        Button(action: action) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 14))
            HStack(spacing: 10) {
                layout {
                    icon
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 68)
            .background(Palette.surface, in: Self.shape)
            .overlay { Self.shape.strokeBorder(Palette.separator, lineWidth: 0.5) }
            .cardDepth(Self.shape, edge: nil)
            .contentShape(Self.shape)
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: 40, height: 40)
            .background(Palette.surface3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 10) {
        EmptyLibraryPathCard(symbol: "pencil", title: "Write it yourself", subtitle: "A blank page, your words.") {}
        EmptyLibraryPathCard(symbol: "doc.text", title: "Import a script", subtitle: "Bring something you already wrote.") {}
    }
    .padding()
    .background(Palette.bg)
}
#endif
