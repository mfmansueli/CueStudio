//
//  TextStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Text style for the picked text. Fixed on top: its words (the keyboard comes up when it was just
/// added) and the tabs, Animated · Styles · Custom, spread over the width (with the largest text sizes, only the tabs).
/// Animated has the six effects in a grid (the creator's own first words in each, the picked one playing its way in,
/// `TextEffectCardSamples`) and the picked one's settings; Styles, "Save style", the creator's styles and Cue's in a grid;
/// Custom, the creator's own look in three sections: Font (with Size and Turn), Color (with Glow) and Motion. Under the
/// look's tabs, what the look changes ("This title" or "All texts · 3": the words, timing and motion are always this
/// text's), the controls, and "Apply this style to captions", which copies the look onto the captions once, after asking.
/// Motion is the picked text's alone. The panel expands (the header's button, or a drag) to give the controls the room the
/// video gives up. While the words are typed only the field and the tabs show, so the video stays big; a tab puts the
/// keyboard away.
struct TextStylePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: UIImage?
    @State private var effectSamples = TextEffectCardSamples()
    @State private var naming: StyleNameRequest?
    @FocusState private var writes: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    /// What the preset cards say.
    private static var sample: String { String(localized: "Big idea", comment: "What the text style cards say: two short words") }
    /// The colors here are what the panel is for: larger than in other panels.
    private static let swatchDiameter: CGFloat = 34

    var body: some View {
        if let text = viewModel.selectedText, let graphic = text.graphic {
            GraphicStylePanel(viewModel: viewModel, text: text, graphic: graphic)
        } else if let text = viewModel.selectedText {
            let tab = viewModel.overlays.textStyleTab
            // With the largest text sizes only the tabs stay fixed: the words scroll with the rest, and
            // the tab's own controls come before the scope, so Font and Color show what they are for.
            let isLarge = typeSize.isAccessibilitySize
            PanelFrame(viewModel: viewModel, panel: .textStyle, play: .motion(viewModel.overlays)) {
                VStack(spacing: 0) {
                    if !isLarge { field(text).padding(.horizontal, 16).padding(.bottom, 4) }
                    // While typing, the words and the tabs (as in CapCut): the video above gets the room the controls
                    // would take (`EditorLayout.typingPanelHeight`); a tab puts the keyboard away and shows its controls.
                    PanelTabs(tabs: EditorPanelTab.textStyle, selection: tab) { picked in
                        writes = false
                        viewModel.overlays.showTextStyleTab(picked)
                    }
                }
            } content: {
                if isLarge { field(text) }
                if !typing || !Self.hidesControlsWhileTyping(typeSize) { lookControls(text, tab: tab, isLarge: isLarge) }
            }
            .task {
                guard frame == nil else { return }
                frame = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240)
            }
            .styleNamePrompt($naming) { purpose, name in
                switch purpose {
                case .save: viewModel.overlays.saveTextStyle(named: name)
                case .rename(let id): viewModel.overlays.renameTextStyle(id, to: name)
                }
            }
            .onAppear(perform: focusIfAsked)
            .onChange(of: viewModel.overlays.focusesTextField) { _, _ in focusIfAsked() }
            .alert(
                "Apply this style to captions?",
                isPresented: Binding(
                    get: { viewModel.captions.captionStyleCopySourceID != nil },
                    set: { if !$0 { viewModel.captions.cancelCopyingStyleToCaptions() } }
                )
            ) {
                Button("Cancel", role: .cancel) { viewModel.captions.cancelCopyingStyleToCaptions() }
                    .accessibilityIdentifier("edit.style.copyToCaptions.cancel")
                Button("Apply") { viewModel.captions.copyStyleToCaptions() }
                    .accessibilityIdentifier("edit.style.copyToCaptions.apply")
            } message: {
                Text(viewModel.captions.captionStyleCopyMessage)
            }
        }
    }

    /// The look's controls under the tabs: Custom's sections, the scope, the tab's own controls, and copying the look to the
    /// captions.
    @ViewBuilder
    private func lookControls(_ text: TextOverlay, tab: EditorPanelTab, isLarge: Bool) -> some View {
        let changesLook = viewModel.overlays.textStyleTabChangesLook
        if tab == .custom { customSections }
        if changesLook, !isLarge { scope }
        switch tab {
        case .animated: animated(text)
        case .custom:
            switch viewModel.overlays.textCustomSection {
            case .color: color(text)
            case .motion: MotionKeyframeControls(viewModel: viewModel)
            default: font(text)
            }
        default: styleCards
        }
        if changesLook, isLarge { scope }
        if changesLook, viewModel.captions.canCopyStyleToCaptions { copyToCaptions }
    }

    /// Custom's sections: Font, Color, Motion (`edit.panel.tab.<section>`).
    private var customSections: some View {
        PanelSegmented(
            options: EditorPanelTab.textCustom.map { PanelOption($0, $0.label) }, selection: viewModel.overlays.textCustomSection,
            height: 38, identifier: "edit.panel.tab"
        ) { viewModel.overlays.showTextStyleTab($0) }
    }

    /// The words are being typed (the keyboard is up for the field).
    private var typing: Bool { writes }

    /// While typing, only the field and the tabs show (`EditorLayout.typingPanelHeight`). With large text they wouldn't fit that
    /// room, so the controls stay and scroll over the keyboard as before.
    static func hidesControlsWhileTyping(_ typeSize: DynamicTypeSize) -> Bool {
        typeSize < .xxLarge
    }

    private func focusIfAsked() {
        guard viewModel.overlays.focusesTextField else { return }
        viewModel.overlays.focusesTextField = false
        writes = true
    }

    // MARK: - Fixed rows

    /// The words: over the tabs, in reach over the keyboard and while the content scrolls.
    private func field(_ text: TextOverlay) -> some View {
        TextField(viewModel.overlays.textFieldPlaceholder, text: Binding(
            get: { text.text },
            set: { viewModel.overlays.setTextContent(text.id, $0) }
        ))
        .font(.system(.body))
        .focused($writes)
        .submitLabel(.done)
        .padding(.horizontal, 14)
        .frame(minHeight: Metrics.buttonHeight)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        .accessibilityIdentifier("edit.textField")
    }

    /// What the look changes: this text or every text. A note says what never follows the scope.
    private var scope: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelSegmented(
                label: String(localized: "Style applies to"),
                options: OverlaysViewModel.textStyleScopes.map { PanelOption($0, viewModel.overlays.textStyleScopeLabel($0)) },
                selection: viewModel.overlays.textStyleScope, height: 38, identifier: "edit.style.scope"
            ) { viewModel.overlays.textStyleScope = $0 }
            if viewModel.overlays.textStyleScope == .allTexts {
                PanelNote(text: String(localized: "Words, timing and motion stay with each text."))
                    .accessibilityIdentifier("edit.style.scopeNote")
            }
        }
    }

    /// Copies the look onto the captions once; asks first (`TextStylePanel.body`'s alert).
    private var copyToCaptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Palette.Editor.separator).frame(height: 0.5)
            PanelButton(
                label: String(localized: "Apply this style to captions"), systemImage: "captions.bubble",
                identifier: "edit.style.copyToCaptions", action: viewModel.captions.askToCopyStyleToCaptions
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Tabs

    /// Animated: the six effects, then the picked one's settings. Its colors are Custom › Color's.
    @ViewBuilder
    private func animated(_ text: TextOverlay) -> some View {
        effectCards(text)
        if let effect = text.effect { TextEffectControls(viewModel: viewModel, effect: effect) }
    }

    /// Cards in a grid that fills the panel: three in a row on an iPhone, as in Caption style.
    private static let cell: CGFloat = 104

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.cell), spacing: 8, alignment: .top)]
    }

    /// The size and the turn, in Custom › Font: Turn is always the picked text's.
    @ViewBuilder
    private func sizeAndTurn() -> some View {
        PanelSlider(
            label: String(localized: "Size"), value: viewModel.overlays.pickedTextPointSize, range: CueSliderSpec.textPoints.range,
            step: CueSliderSpec.textPoints.step ?? 2, defaultValue: CueSliderSpec.textPoints.defaultValue, format: .points, identifier: "edit.textSize"
        ) { viewModel.overlays.restyleText(.size($0), key: "textSize") }
        PanelSlider(
            label: String(localized: "Turn"), value: viewModel.overlays.pickedTextTurnDegrees, range: CueSliderSpec.textTurn.range,
            step: CueSliderSpec.textTurn.step ?? 1, defaultValue: CueSliderSpec.textTurn.defaultValue, format: .degrees,
            identifier: "edit.textTurn", onChange: { viewModel.overlays.setTextTurn(degrees: $0) },
            onEditingChanged: { $0 ? viewModel.overlays.beginPanelChange() : viewModel.overlays.endPanelChange() }
        )
    }

    /// The six effects, each drawn on the creator's own first words by the export's renderer; the picked one plays its way
    /// in (still with Reduce Motion). Favorites first; held, a card has the styles' menu.
    private func effectCards(_ text: TextOverlay) -> some View {
        let overlays = viewModel.overlays
        let library = overlays.textStyles
        let effects = TypePreset.effectPresets.sorted { library.isFavorite(.builtIn($0.rawValue)) && !library.isFavorite(.builtIn($1.rawValue)) }
        let words = TextEffectCardSamples.sample(of: text, fallback: Self.sample)
        let picked = text.effect != nil ? overlays.pickedTextPreset : nil
        return LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(effects) { preset in
                let key = StyleKey.builtIn(preset.rawValue)
                PanelPresetCard(
                    name: preset.label, sample: effectSamples.stills[preset], motion: effectSamples.motions[preset], frame: frame,
                    isSelected: picked == preset, isFavorite: library.isFavorite(key), isDefault: library.isDefault(key),
                    summary: preset.effect?.summary, identifier: "edit.style.\(preset.rawValue)",
                    action: { overlays.pickTextPreset(preset) },
                    menu: {
                        StyleCardMenu(
                            isFavorite: library.isFavorite(key), isDefault: library.isDefault(key),
                            defaultLabel: String(localized: "Use for new texts"),
                            onFavorite: { overlays.toggleFavoriteTextStyle(key) },
                            onDefault: { overlays.toggleDefaultTextStyle(key, name: preset.label) },
                            onDuplicate: { overlays.duplicateTextStyle(key, name: preset.label) }
                        )
                    }
                )
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.textEffects")
        .task(id: EffectSampleRequest(words: words, picked: picked, plays: !reduceMotion)) {
            effectSamples.prepare(words: words, picked: picked, plays: !reduceMotion)
        }
    }

    /// Styles: "Save style", the creator's styles (favorites first) and Cue's presets in a grid; each held for its menu.
    private var styleCards: some View {
        let library = viewModel.overlays.textStyles
        let saved = library.styles.sorted { library.isFavorite($0.key) && !library.isFavorite($1.key) }
        let presets = TypePreset.editorPresets.sorted { library.isFavorite(.builtIn($0.rawValue)) && !library.isFavorite(.builtIn($1.rawValue)) }
        return LazyVGrid(columns: gridColumns, spacing: 12) {
            PanelSaveStyleCard {
                naming = StyleNameRequest(purpose: .save, name: viewModel.overlays.suggestedTextStyleName)
            }
            ForEach(saved) { style in savedCard(style, library: library) }
            ForEach(presets) { preset in presetCard(preset, library: library) }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.textStyles")
    }

    private func savedCard(_ style: SavedStyle<TextLook>, library: StyleLibrary<TextLook>) -> some View {
        let overlays = viewModel.overlays
        return PanelPresetCard(
            name: style.name, sample: TypeLookPreview.image(style.look, use: .title, sample: Self.sample), frame: frame,
            isSelected: overlays.pickedTextSavedStyleID == style.id, isFavorite: library.isFavorite(style.key),
            isDefault: library.isDefault(style.key), identifier: "edit.style.saved.\(style.id.uuidString)",
            action: { overlays.pickSavedTextStyle(style.id) },
            menu: {
                StyleCardMenu(
                    isFavorite: library.isFavorite(style.key), isDefault: library.isDefault(style.key),
                    defaultLabel: String(localized: "Use for new texts"),
                    onFavorite: { overlays.toggleFavoriteTextStyle(style.key) },
                    onDefault: { overlays.toggleDefaultTextStyle(style.key, name: style.name) },
                    onDuplicate: { overlays.duplicateTextStyle(style.key, name: style.name) },
                    onRename: { naming = StyleNameRequest(purpose: .rename(style.id), name: style.name) },
                    onUpdate: { overlays.updateTextStyle(style.id) },
                    onDelete: { overlays.deleteTextStyle(style.id) }
                )
            }
        )
    }

    private func presetCard(_ preset: TypePreset, library: StyleLibrary<TextLook>) -> some View {
        let overlays = viewModel.overlays
        let key = StyleKey.builtIn(preset.rawValue)
        return PanelPresetCard(
            name: preset.label, sample: TypeLookPreview.image(preset.look(for: .title), use: .title, sample: Self.sample),
            frame: frame, isSelected: overlays.pickedTextPreset == preset && overlays.pickedTextSavedStyleID == nil, isFavorite: library.isFavorite(key),
            isDefault: library.isDefault(key), identifier: "edit.style.\(preset.rawValue)",
            action: { overlays.pickTextPreset(preset) },
            menu: {
                StyleCardMenu(
                    isFavorite: library.isFavorite(key), isDefault: library.isDefault(key), defaultLabel: String(localized: "Use for new texts"),
                    onFavorite: { overlays.toggleFavoriteTextStyle(key) },
                    onDefault: { overlays.toggleDefaultTextStyle(key, name: preset.label) },
                    onDuplicate: { overlays.duplicateTextStyle(key, name: preset.label) }
                )
            }
        )
    }

    /// Size and Turn first, one row each and always in sight; then the fonts, the script libraries the words call for, an imported
    /// one, and the weight.
    @ViewBuilder
    private func font(_ text: TextOverlay) -> some View {
        sizeAndTurn()
        PanelChips(
            options: TextOverlayFont.pickerFonts(including: text.font).map { PanelOption($0, $0.label) }, selection: text.font,
            font: { CueStudioFont.chip($0, size: $1) }, identifier: "edit.textFont",
            onSelect: { viewModel.overlays.restyleText(.font($0)) }
        )
        if let note = viewModel.brand.missingFontNote(text.font) { PanelNote(text: note) }
        ScriptFontLibraries(
            scripts: viewModel.brand.scriptLibraries(styling: text.displayText), store: viewModel.brand.fontPacks, selection: text.font,
            weight: text.weight, identifier: "edit.textFont", onSelect: { viewModel.overlays.restyleText(.font($0)) }
        )
        FontImportButton(viewModel: viewModel) { viewModel.overlays.restyleText(.font($0)) }
        PanelSegmented(
            label: String(localized: "Weight"), options: text.font.weights.map { PanelOption($0, $0.label) },
            selection: text.weight, height: 38, identifier: "edit.textWeight"
        ) { viewModel.overlays.restyleText(.weight($0)) }
    }

    /// The colors; for a text without an effect, its Glow too (an effect makes its own light).
    @ViewBuilder
    private func color(_ text: TextOverlay) -> some View {
        if let effect = text.effect {
            effectColor(text, effect: effect)
        } else {
            typeColor(text)
            PanelSlider(
                label: String(localized: "Glow"), value: text.glow * 100, range: CueSliderSpec.textGlow.range,
                step: CueSliderSpec.textGlow.step ?? 5, defaultValue: CueSliderSpec.textGlow.defaultValue, format: .percent,
                identifier: "edit.textGlow"
            ) { viewModel.overlays.restyleText(.glow($0 / 100), key: "textGlow") }
        }
    }

    /// An effect's colors: its metal or the text's color, and its second color; it makes its own light and shadow.
    @ViewBuilder
    private func effectColor(_ text: TextOverlay, effect: TextEffect) -> some View {
        if effect.kind.usesTone {
            PanelSegmented(
                label: String(localized: "Metal"), options: MetalTone.allCases.map { PanelOption($0, $0.label) },
                selection: effect.tone, height: 38, identifier: "edit.textEffect.tone"
            ) { viewModel.overlays.restyleText(.effectTone($0)) }
        }
        if effect.kind.usesTextColor {
            PanelSwatches(
                label: String(localized: "Text"), colors: OverlayColor.palette, selection: text.color,
                diameter: Self.swatchDiameter, identifier: "edit.textColor"
            ) { viewModel.overlays.restyleText(.color($0)) }
        }
        if effect.kind.usesAccent {
            PanelSwatches(
                label: effect.kind.accentLabel, colors: OverlayColor.palette, selection: effect.accent,
                diameter: Self.swatchDiameter, identifier: "edit.textEffect.accent"
            ) { viewModel.overlays.restyleText(.effectAccent($0)) }
        }
        PanelNote(text: String(localized: "The effect makes its own light and shadow. Remove it in Animated to use a background or an outline."))
            .accessibilityIdentifier("edit.textEffect.colorNote")
    }

    @ViewBuilder
    private func typeColor(_ text: TextOverlay) -> some View {
        PanelSwatches(
            label: String(localized: "Text"), colors: OverlayColor.palette, selection: text.color,
            diameter: Self.swatchDiameter, identifier: "edit.textColor"
        ) { viewModel.overlays.restyleText(.color($0)) }
        PanelSegmented(
            label: String(localized: "Background"), options: TextOverlayBackground.allCases.map { PanelOption($0, $0.label) },
            selection: text.background, height: 38, identifier: "edit.textBackground"
        ) { viewModel.overlays.restyleText(.background($0)) }
        if text.background != .none {
            PanelSwatches(
                label: String(localized: "Background color"), colors: OverlayColor.palette,
                selection: text.backgroundColor, diameter: Self.swatchDiameter, identifier: "edit.textBackgroundColor"
            ) { viewModel.overlays.restyleText(.backgroundColor($0)) }
        }
        PanelSegmented(
            label: String(localized: "Shadow"), options: TextShadowStyle.allCases.map { PanelOption($0, $0.label) },
            selection: TextShadowStyle(hasShadow: text.hasShadow, hasOutline: text.hasOutline), height: 38, identifier: "edit.textShadow"
        ) { viewModel.overlays.restyleText(.shadow($0)) }
    }
}
