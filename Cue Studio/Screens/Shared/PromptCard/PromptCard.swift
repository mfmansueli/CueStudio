//
//  PromptCard.swift
//  Cue Studio
//

import SwiftUI

/// The highlighted way in to "Generate with AI": describe the video, get a script. Shown at the top
/// of "New script" and of the empty library.
struct PromptCard: View {
    /// The card sits on the sheet (`surface`) or on the screen background, so its base follows.
    var base: Color = Palette.surface2
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
                Text("Describe any video and get a ready-to-read script — in your voice.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("2 minutes on how the electric shower was invented in Brazil")
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
}

#if DEBUG
#Preview {
    PromptCard(action: {})
        .padding()
        .background(Palette.surface)
}
#endif
