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
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Palette.acc)
                    Text("Prompt")
                        .font(.title3.bold())
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Text("Apple Intelligence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.ink2)
                }
                if layout == .full {
                    Text("Describe any video and get a ready-to-read script — in your voice.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink3)
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(base)
                shape.fill(LinearGradient(
                    stops: [.init(color: Palette.accWash, location: 0), .init(color: Palette.accWashFaint, location: 0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            }
            .overlay(shape.strokeBorder(Palette.accBorder, lineWidth: 0.5))
            .contentShape(shape)
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
