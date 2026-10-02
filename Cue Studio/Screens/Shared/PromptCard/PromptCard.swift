//
//  PromptCard.swift
//  Cue Studio
//

import SwiftUI

/// The highlighted way in to "Generate with AI": describe the video, get a script. Always at the top
/// of Scripts, "New script" and the empty library.
struct PromptCard: View {
    enum Layout {
        /// Explains itself and shows an example (New script, empty library).
        case full
        /// Just the title and the field (Scripts, above the search).
        case compact
    }

    /// The card sits on the sheet (`surface`) or on the screen background, so its base follows.
    var base: Color = Palette.surface2
    var layout: Layout = .full
    var animatesBackground = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PromptCardSurface(base: base, animatesBackground: animatesBackground) {
                VStack(alignment: .leading, spacing: 12) {
                    PromptCardHeader(title: "Prompt", animatesBackground: animatesBackground)
                    if layout == .full {
                        Text("Describe any video and get a ready-to-read script — in your voice.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        Text(placeholder)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.accInk)
                            .frame(width: 34, height: 34)
                            .background(Palette.acc, in: Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 6)
                    .frame(minHeight: 46)
                    .background(Palette.insetField, in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Prompt, with Apple Intelligence"))
        .accessibilityHint(Text("Describe any video and get a ready-to-read script"))
        .accessibilityAddTraits(.isButton)
    }

    private var placeholder: LocalizedStringKey {
        switch layout {
        case .full: "2 minutes on how the electric shower was invented in Brazil"
        case .compact: "Describe your next video…"
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        PromptCard(action: {})
        PromptCard(base: Palette.surface, layout: .compact, action: {})
    }
    .padding()
    .background(Palette.bg)
}
#endif
