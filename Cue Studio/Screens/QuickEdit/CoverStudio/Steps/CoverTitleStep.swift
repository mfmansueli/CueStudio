//
//  CoverTitleStep.swift
//  Cue Studio
//

import SwiftUI

/// Title: the words (or one Cue suggests from the take), which words stand out, then how they're set, in groups: Type (font,
/// size, block width, alignment, capitals), Color (text, highlight and how it shows), Readability (shadow, outline or box) and
/// the small line over them. The block always fits the cover; when even the smallest size can't, it says to shorten it.
struct CoverTitleStep: View {
    let viewModel: CoverStudioViewModel

    @FocusState private var isTyping: Bool
    /// A word of the title to highlight, growing with the text size.
    @ScaledMetric(relativeTo: .subheadline) private var wordSize: CGFloat = 14

    private var style: CoverTitleStyle { viewModel.composition.title }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            field
            if viewModel.titleOverflows {
                PanelNote(text: String(localized: "Too long to fit. Shorten the title or make the block wider."))
            }
            if !viewModel.suggestions.isEmpty, viewModel.cover.title.isEmpty || isTyping { suggestions }
            if viewModel.titleWords.count > 1 { highlights }
            group(String(localized: "Type")) {
                // The same families as the texts and captions on the video, each chip in its own face.
                PanelChips(
                    options: TextOverlayFont.editorFonts.map { PanelOption($0, $0.label) }, selection: style.font.face,
                    font: { CueStudioFont.chip($0, size: $1) }, identifier: "cover.font",
                    onSelect: { face in viewModel.updateTitle { $0.font = CoverFont(face, weight: $0.font.weight) } }
                )
                if style.font.face.weights.count > 1 {
                    PanelSegmented(
                        label: String(localized: "Weight"), options: style.font.face.weights.map { PanelOption($0, $0.label) },
                        selection: style.font.weight, height: 38, identifier: "cover.weight"
                    ) { weight in viewModel.updateTitle { $0.font = CoverFont($0.font.face, weight: weight) } }
                }
                PanelSlider(
                    label: String(localized: "Size"), value: style.size * 1000,
                    range: CoverTitleStyle.sizeRange.lowerBound * 1000...CoverTitleStyle.sizeRange.upperBound * 1000, step: 5,
                    format: .plain, identifier: "cover.titleSize",
                    onChange: { value in viewModel.updateTitle { $0.size = value / 1000 } }, onEditingChanged: gesture
                )
                PanelSlider(
                    label: String(localized: "Width"), value: style.width * 100,
                    range: CoverTitleStyle.widthRange.lowerBound * 100...CoverTitleStyle.widthRange.upperBound * 100, step: 1,
                    format: .percent, identifier: "cover.titleWidth",
                    onChange: { value in viewModel.updateTitle { $0.width = value / 100 } }, onEditingChanged: gesture
                )
                PanelSegmented(
                    options: LineAlignment.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage) },
                    selection: style.alignment, identifier: "cover.alignment"
                ) { alignment in viewModel.updateTitle { $0.alignment = alignment } }
                PanelToggleRow(label: String(localized: "Capitals"), isOn: style.uppercase, identifier: "cover.uppercase") {
                    viewModel.updateTitle { $0.uppercase.toggle() }
                }
            }
            group(String(localized: "Color")) {
                PanelSwatches(
                    label: String(localized: "Text"), colors: OverlayColor.palette, selection: style.textColor, identifier: "cover.textColor"
                ) { color in
                    viewModel.updateTitle { $0.textColor = color }
                }
                PanelSwatches(label: String(localized: "Highlight"), colors: OverlayColor.palette, selection: style.accent, identifier: "cover.accent") { color in
                    viewModel.updateTitle { $0.accent = color }
                }
                PanelSegmented(
                    label: String(localized: "Highlight shows as"),
                    options: CoverHighlightStyle.allCases.map { PanelOption($0, $0.label) }, selection: style.highlightStyle,
                    identifier: "cover.highlightStyle"
                ) { highlight in viewModel.updateTitle { $0.highlightStyle = highlight } }
            }
            group(String(localized: "Readability")) {
                PanelSegmented(
                    options: CoverTextBackground.allCases.map { PanelOption($0, $0.label) }, selection: style.background,
                    identifier: "cover.background"
                ) { background in viewModel.updateTitle { $0.background = background } }
                if style.background == .box {
                    PanelSwatches(
                        label: String(localized: "Box"), colors: OverlayColor.palette, selection: style.boxColor, identifier: "cover.boxColor"
                    ) { color in viewModel.updateTitle { $0.boxColor = color } }
                }
            }
            group(String(localized: "Line above")) {
                TextField(String(localized: "EP 03, HOW TO, PART 2…"), text: Binding(
                    get: { style.kicker }, set: { text in viewModel.updateTitle { $0.kicker = String(text.prefix(24)) } }
                ))
                .font(.system(.callout))
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: Metrics.hitTarget)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                .accessibilityIdentifier("cover.kicker")
            }
        }
    }

    private var field: some View {
        TextField(String(localized: "Title on the cover"), text: Binding(get: { viewModel.cover.title }, set: { viewModel.setTitle($0) }))
            .font(.system(.body, weight: .semibold))
            .focused($isTyping)
            .onSubmit { isTyping = false }
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: Metrics.hitTarget)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .accessibilityIdentifier("cover.titleField")
    }

    private var suggestions: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        viewModel.setTitle(suggestion)
                        isTyping = false
                    } label: {
                        Text("✦ " + suggestion)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(Palette.aiTextStrong)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Palette.aiFill, in: Capsule())
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.cuePress)
                    .accessibilityIdentifier("cover.suggestion.\(index)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// The words to tap to make them stand out (any number of them).
    private var highlights: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelRowLabel(label: String(localized: "Words that stand out"))
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.titleWords.enumerated()), id: \.offset) { index, word in
                        let isOn = style.highlights.contains(index)
                        Button { viewModel.toggleHighlight(index) } label: {
                            Text(style.uppercase ? word.localizedUppercase : word)
                                .font(.system(size: wordSize, weight: .semibold))
                                .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
                                .padding(.horizontal, 11)
                                .frame(height: 32)
                                .background(isOn ? Palette.chipOn : Palette.fill, in: Capsule())
                                .frame(minHeight: Metrics.hitTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityIdentifier("cover.highlight.\(index)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(Palette.ink2)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(12)
        .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func gesture(_ editing: Bool) {
        if editing { viewModel.beginGesture() } else { viewModel.endGesture() }
    }
}
