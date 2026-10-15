//
//  EmptyLibraryPathCard.swift
//  Cue Studio
//

import SwiftUI

/// One way in on the empty Scripts ("Find inspiration", "Write it yourself", "Import a script"): a softly rounded dark card with a hairline,
/// the icon in a small tinted square on the left, the title and a line under it, and a disclosure chevron. The whole card is the button.
/// At the biggest text sizes the icon goes above the words, so the words keep the width.
struct EmptyLibraryPathCard: View {
    enum Tint {
        /// The app's yellow (the way the screen leads with).
        case accent
        /// A quiet grey square with a white icon.
        case neutral
    }

    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var tint: Tint = .neutral
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
            .foregroundStyle(tint == .accent ? Palette.accText : Palette.ink)
            .frame(width: 40, height: 40)
            .background(tint == .accent ? Palette.accSoft : Palette.surface3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 10) {
        EmptyLibraryPathCard(
            symbol: FindInspirationSheet.symbol, title: "Find inspiration", subtitle: "Discover video ideas from your topics.", tint: .accent
        ) {}
        EmptyLibraryPathCard(symbol: "pencil", title: "Write it yourself", subtitle: "A blank page, your words.") {}
    }
    .padding()
    .background(Palette.bg)
}
#endif
