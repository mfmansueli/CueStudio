//
//  PrompterParagraphs.swift
//  Cue Studio
//

import SwiftUI

/// The prompter's text itself, paragraph by paragraph, as the teleprompter draws it (font, size, spacing, alignment, colour, margins and
/// the AI Coach cues). Equatable so scrolling never re-lays it out. Also drawn by Settings › Prompter's preview, so the preview's text is
/// the prompter's own.
struct PrompterParagraphs: View, Equatable {
    let paragraphs: [String]
    let settings: PrompterSettings
    let fontSize: Double
    /// Where each paragraph sits (index, top..<bottom), so Voice follow can put a word on the guide.
    var onParagraphFrame: (Int, Range<Double>) -> Void = { _, _ in }

    private nonisolated static let space = "prompter.paragraphs"

    var body: some View {
        VStack(alignment: settings.alignment.horizontalAlignment, spacing: fontSize * settings.lineSpacing * 0.75) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                Text(styled(paragraph))
                .font(settings.font.font(size: fontSize))
                .fontWeight(.medium)
                .lineSpacing(max(0, fontSize * (settings.lineSpacing - 1.2)))
                .multilineTextAlignment(settings.alignment.textAlignment)
                .frame(maxWidth: .infinity, alignment: settings.alignment.frameAlignment)
                .onGeometryChange(for: Range<Double>.self) { proxy in
                    let frame = proxy.frame(in: .named(Self.space))
                    return Double(frame.minY)..<Double(max(frame.minY, frame.maxY))
                } action: { frame in
                    onParagraphFrame(index, frame)
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .foregroundStyle(settings.textColor.color)
        .padding(.horizontal, settings.margin)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The paragraph as drawn: one even colour, so nothing in the text asks for the eye while it scrolls with the voice.
    private func styled(_ paragraph: String) -> AttributedString {
        CueAttributedText.make(
            paragraph,
            showsCues: settings.showsCues,
            // AI Coach cues stay small and quiet so the spoken words lead.
            cueFont: settings.font.font(size: fontSize * 0.42).weight(.bold),
            cueBackground: Palette.accCueWash
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.paragraphs == rhs.paragraphs && lhs.settings == rhs.settings && lhs.fontSize == rhs.fontSize
    }
}
