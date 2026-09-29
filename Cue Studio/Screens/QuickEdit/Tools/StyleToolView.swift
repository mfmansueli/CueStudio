//
//  StyleToolView.swift
//  Cue Studio
//

import SwiftUI

/// Style: Clean, Bold, Minimal or Social for the whole video. One tap sets every text, the
/// captions' style and the filter; new texts start from it. Undo takes it back.
struct StyleToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(CreatorStyle.allCases) { style in
                    let isOn = viewModel.edit.creatorStyle == style
                    Button { viewModel.applyCreatorStyle(style) } label: {
                        SelectableCard(isSelected: isOn) {
                            VStack(alignment: .leading, spacing: 3) {
                                sample(style)
                                Text(style.label).font(.subheadline.weight(.semibold))
                                Text(style.detail)
                                    .font(.caption)
                                    .foregroundStyle(Palette.ink2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("edit.style.\(style.rawValue)")
                }
            }
            Text("Sets your texts, captions and filter in one tap")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
        }
    }

    /// "Aa" set the way the style sets a title.
    private func sample(_ style: CreatorStyle) -> some View {
        var text = TextOverlay(role: .title, style: style, span: TimeSpan(start: 0, end: 1))
        text.text = "Aa"
        let font: Font = switch text.font {
        case .classic: .system(size: 17, weight: weight(text.weight))
        case .rounded: .system(size: 17, weight: weight(text.weight), design: .rounded)
        case .serif: .system(size: 17, weight: weight(text.weight), design: .serif)
        case .mono: .system(size: 17, weight: weight(text.weight), design: .monospaced)
        }
        return Text(text.displayText)
            .font(font)
            .foregroundStyle(text.color.color)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(text.background == .none ? Color.clear : text.backgroundColor.color, in: Capsule())
            .accessibilityHidden(true)
    }

    private func weight(_ weight: TextOverlayWeight) -> Font.Weight {
        switch weight {
        case .regular: .regular
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}
