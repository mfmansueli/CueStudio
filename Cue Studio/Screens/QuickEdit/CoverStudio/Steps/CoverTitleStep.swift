//
//  CoverTitleStep.swift
//  Cue Studio
//

import SwiftUI

/// Title: the words (or one Cue suggests from the take, never the one already there), then Words · Type · Color · Box under the
/// field: Words (which words stand out, the small line above), Type (font, size, block width, alignment, capitals), Color (text,
/// highlight and how it shows), Box (none, shadow, outline or a box). Words comes first so that, with the keyboard up, the field
/// and what follows typing stay in view. The block always fits the cover; when even the smallest size can't, it says to shorten it.
struct CoverTitleStep: View {
    @Bindable var viewModel: CoverStudioViewModel

    @FocusState private var isTyping: Bool
    /// A word of the title to highlight, growing with the text size.
    @ScaledMetric(relativeTo: .subheadline) private var wordSize: CGFloat = 14

    private var style: CoverTitleStyle { viewModel.composition.title }

    var body: some View {
        // 8 pt apart: with the keyboard up on an iPhone SE, the field, the suggestions, Words and the highlighted words all fit.
        VStack(alignment: .leading, spacing: 8) {
            field
            if viewModel.titleOverflows {
                PanelNote(text: String(localized: "Too long to fit. Shorten the title or make the block wider."))
            }
            let offered = viewModel.offeredSuggestions
            if !offered.isEmpty, viewModel.cover.title.isEmpty || isTyping { suggestions(offered) }
            PanelSegmented(
                options: CoverTitleSection.allCases.map { PanelOption($0, $0.label) }, selection: viewModel.titleSection,
                identifier: "cover.titleSection"
            ) { viewModel.titleSection = $0 }
            VStack(alignment: .leading, spacing: 14) {
                switch viewModel.titleSection {
                case .words: words
                case .type: type
                case .color: color
                case .box: box
                }
            }
        }
    }

    // MARK: - Sections

    /// Which words stand out, and the small line above them.
    @ViewBuilder
    private var words: some View {
        if viewModel.titleWords.count > 1 { highlights }
        VStack(alignment: .leading, spacing: 6) {
            PanelRowLabel(label: String(localized: "Line above"))
            TextField(String(localized: "EP 03, HOW TO, PART 2…"), text: Binding(
                get: { style.kicker }, set: { text in viewModel.updateTitle(key: "cover.kicker") { $0.kicker = String(text.prefix(24)) } }
            ))
            .font(.system(.callout))
            .submitLabel(.done)
            .padding(.horizontal, 12)
            .frame(height: Metrics.hitTarget)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .accessibilityLabel(Text("Line above"))
            .accessibilityIdentifier("cover.kicker")
        }
    }

    @ViewBuilder
    private var type: some View {
        // The same families as the texts and captions on the video, each chip in its own face.
        PanelChips(
            options: TextOverlayFont.pickerFonts(including: style.font.face).map { PanelOption($0, $0.label) }, selection: style.font.face,
            font: { CueStudioFont.chip($0, size: $1) }, identifier: "cover.font",
            onSelect: { face in viewModel.updateTitle { $0.font = CoverFont(face, weight: $0.font.weight) } }
        )
        if let store = viewModel.fontPacks {
            ScriptFontLibraries(
                scripts: viewModel.scriptLibraries, store: store, selection: style.font.face, weight: style.font.weight,
                identifier: "cover.font", onSelect: { face in viewModel.updateTitle { $0.font = CoverFont(face, weight: $0.font.weight) } }
            )
        }
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

    @ViewBuilder
    private var color: some View {
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

    /// What keeps the words readable on the picture: nothing, a shadow, an outline or a box (and its color).
    @ViewBuilder
    private var box: some View {
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

    // MARK: - Parts

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

    private func suggestions(_ offered: [String]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(offered.enumerated()), id: \.offset) { index, suggestion in
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

    private func gesture(_ editing: Bool) {
        if editing { viewModel.beginGesture() } else { viewModel.endGesture() }
    }
}
