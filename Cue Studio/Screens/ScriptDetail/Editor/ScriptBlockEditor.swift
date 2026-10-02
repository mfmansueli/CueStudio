//
//  ScriptBlockEditor.swift
//  Cue Studio
//

import SwiftUI

/// The script as blocks to write in: each paragraph under the label of the block it plays (Hook,
/// Body, CTA…) with the block's read time, all in one scroll view. Return starts a new paragraph;
/// Backspace at the start of one joins it to the one before.
struct ScriptBlockEditor: View {
    let viewModel: ScriptDetailViewModel
    let size: ScriptTextSize

    var body: some View {
        let labels = viewModel.editorLabels
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.draftParagraphs.indices, id: \.self) { index in
                    block(index, label: labels.indices.contains(index) ? labels[index] : nil)
                }
                // The empty room under the last paragraph is a tap on it.
                Color.clear
                    .frame(height: 120)
                    .contentShape(Rectangle())
                    .onTapGesture { focusLastParagraph() }
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Metrics.textGutter)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func block(_ index: Int, label: EditorBlockLabel?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label, label.showsLabel {
                blockHeader(label)
            }
            ZStack(alignment: .topLeading) {
                if viewModel.draftParagraphs[index].isEmpty {
                    ParagraphPlaceholder(text: placeholder(forParagraph: index), points: size.points)
                }
                ParagraphTextView(
                    index: index,
                    text: viewModel.draftParagraphs[index],
                    size: size,
                    focus: viewModel.focus,
                    onChange: { viewModel.setParagraph(index, to: $0) },
                    onLineBreak: { viewModel.replaceParagraph(index, with: $0, caret: $1) },
                    onBackspaceAtStart: { viewModel.mergeWithPrevious(index) },
                    onMove: { viewModel.moveCaret(from: index, by: $0) },
                    onCaret: { viewModel.noteCaret(paragraph: index, offset: $0) },
                    onBeginEditing: { viewModel.noteFocus(paragraph: index) },
                    onEndEditing: { viewModel.noteBlur(paragraph: index) }
                )
            }
        }
    }

    /// "HOOK ———— ~6s": the block's name, a hairline and how long it reads.
    private func blockHeader(_ label: EditorBlockLabel) -> some View {
        HStack(spacing: 8) {
            Text(label.label)
                .textCase(.uppercase)
                .kerning(0.9)
            Rectangle()
                .fill(Palette.separator)
                .frame(height: 0.5)
            if let seconds = label.groupSeconds {
                Text("~\(DurationText.short(seconds))")
                    .monospacedDigit()
            }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Palette.ink2)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// What an empty paragraph asks for, by the block it plays.
    private func placeholder(forParagraph index: Int) -> String {
        let count = viewModel.draftParagraphs.count
        if count == 1 { return String(localized: "Start writing what you want to say… Tap [ ] to add cues.") }
        if index == 0 {
            return viewModel.structure.isSerious
                ? String(localized: "Start plainly and directly")
                : String(localized: "Open with the line that stops the scroll")
        }
        if index == count - 1, viewModel.structure.blocks.last == String(localized: "CTA") {
            return String(localized: "Tell them what to do next")
        }
        return String(localized: "Keep going…")
    }

    private func focusLastParagraph() {
        let last = viewModel.draftParagraphs.count - 1
        guard last >= 0 else { return }
        viewModel.focus = .at(last, offset: viewModel.draftParagraphs[last].utf16.count)
    }
}
