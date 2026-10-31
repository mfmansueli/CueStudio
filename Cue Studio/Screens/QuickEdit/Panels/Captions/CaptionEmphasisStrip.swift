//
//  CaptionEmphasisStrip.swift
//  Cue Studio
//

import SwiftUI

/// Caption line › More › Emphasis: the line's words as chips; a tap marks a word for emphasis (the style's emphasis color and
/// size, for as long as the line shows, unlike the word being said) or unmarks it, one undo step each. More than two in a line
/// stop reading as emphasis: a note says so.
struct CaptionEmphasisStrip: View {
    let viewModel: QuickEditViewModel
    let cueID: UUID

    var body: some View {
        let words = viewModel.captions.captionEmphasisWords(cueID)
        if viewModel.captions.canMarkCaptionEmphasis, !words.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                PanelRowLabel(label: String(localized: "Emphasis"), detail: String(localized: "Tap the words that matter"))
                FlowLayout(spacing: 6) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        chip(word.word, isMarked: word.isMarked) { viewModel.captions.toggleCaptionEmphasis(cueID, word: index) }
                    }
                }
                if viewModel.captions.hasTooMuchEmphasis(cueID) {
                    PanelNote(text: String(localized: "Emphasis reads best on one or two words a line."), teaches: true)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("edit.captionEmphasis")
        }
    }

    private func chip(_ word: String, isMarked: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 4) {
                if isMarked { Image(systemName: "star.fill").font(.system(.caption2, weight: .bold)) }
                Text(word).font(.system(.subheadline, weight: isMarked ? .bold : .regular))
            }
            .foregroundStyle(isMarked ? Palette.chipOnInk : Palette.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(isMarked ? Palette.chipOn : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(word))
        .accessibilityValue(isMarked ? Text("Emphasized") : Text(verbatim: ""))
        .accessibilityAddTraits(isMarked ? .isSelected : [])
    }
}
