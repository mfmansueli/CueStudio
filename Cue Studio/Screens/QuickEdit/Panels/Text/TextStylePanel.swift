//
//  TextStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Text style for the picked text. Fixed on top: its words (the keyboard comes up when it was just
/// added) and the tabs, Styles · Font · Color · Motion, spread over the width (with the largest text sizes, only the tabs): one
/// level of tabs (owner, canvas 2 R3). Styles has the filters All · Animated · Mine and the cards in a grid: the creator's styles
/// with "Save style" last (or last of All while there are none), the six that play their way in (the creator's own first words
/// in each, the picked one playing, `TextEffectCardSamples`) with the picked one's settings right under them, and Cue's. Font has
/// Size and Turn; Color, Glow. In the header, in the subtitle's place, what the look changes ("This title | All 3 texts",
/// `TextScopeChoice`, R2: the words, timing and motion are always this text's); under the look's tabs, "Apply this style to
/// captions", which copies the look onto the captions once, after asking. Motion is the picked text's alone. The panel
/// expands (the header's button, or a drag) to give the controls the room the video gives up. While the words are typed
/// only the field and the tabs show, so the video stays big; a tab puts the
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
            let changesLook = viewModel.overlays.textStyleTabChangesLook
            // While the words are typed, the subtitle instead: the field and the tabs keep their room over the keyboard.
            let offersScope = changesLook && !typing && viewModel.overlays.offersTextStyleScope
            let scope = offersScope ? AnyView(TextScopeChoice(overlays: viewModel.overlays)) : nil
            PanelFrame(viewModel: viewModel, panel: .textStyle, play: .motion(viewModel.overlays), subtitleChoice: scope) {
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
                if !typing || !Self.hidesControlsWhileTyping(typeSize) { lookControls(text, tab: tab) }
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

    /// The tab's own controls, and copying the look to the captions.
    @ViewBuilder
    private func lookControls(_ text: TextOverlay, tab: EditorPanelTab) -> some View {
        switch tab {
        case .font: font(text)
        case .color: color(text)
        case .motion: MotionKeyframeControls(viewModel: viewModel)
        default: styles(text)
        }
        if tab != .motion, viewModel.captions.canCopyStyleToCaptions { copyToCaptions }
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

    /// Styles: the filters, then in All the creator's styles, the animated ones with the picked one's settings right under them,
    /// and Cue's, each group under its name; "Save style" is the last of the creator's, or of All while there are none.
    @ViewBuilder
    private func styles(_ text: TextOverlay) -> some View {
        let overlays = viewModel.overlays
        let filter = overlays.textStyleFilter
        let hasMine = !overlays.textStyles.styles.isEmpty
        PanelChips(
            options: TextStyleFilter.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) }, selection: filter,
            identifier: "edit.textFilter"
        ) { overlays.textStyleFilter = $0 }
        switch filter {
        case .all:
            if hasMine { section(TextStyleFilter.mine.label) { savedCards(savesLast: true) } }
            section(TextStyleFilter.animated.label) { effectCards(text) }
            if let effect = text.effect { TextEffectControls(viewModel: viewModel, effect: effect) }
            section(String(localized: "Made by Cue")) { presetCards(savesLast: !hasMine) }
        case .animated:
            effectCards(text)
            if let effect = text.effect { TextEffectControls(viewModel: viewModel, effect: effect) }
        case .mine:
            if !hasMine {
                PanelNote(text: String(localized: "Save the look on screen to use it in your next videos."))
                    .accessibilityIdentifier("edit.textStyles.mineEmpty")
            }
            savedCards(savesLast: true)
        }
    }

    /// A group of cards under its name.
    private func section(_ title: String, @ViewBuilder cards: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            cards()
        }
    }

    /// Cards in a grid that fills the panel: three in a row on an iPhone, as in Caption style.
    private static let cell: CGFloat = 104

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.cell), spacing: 8, alignment: .top)]
    }

    /// The size and the turn, in Font: Turn is always the picked text's.
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

    /// The creator's styles (favorites first), each held for its menu, "Save style" last when `savesLast`.
    private func savedCards(savesLast: Bool) -> some View {
        let library = viewModel.overlays.textStyles
        let saved = library.styles.sorted { library.isFavorite($0.key) && !library.isFavorite($1.key) }
        return LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(saved) { style in savedCard(style, library: library) }
            if savesLast { saveCard }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.textStylesMine")
    }

    /// Cue's presets (favorites first), each held for its menu, "Save style" last when `savesLast`.
    private func presetCards(savesLast: Bool) -> some View {
        let library = viewModel.overlays.textStyles
        let presets = TypePreset.editorPresets.sorted { library.isFavorite(.builtIn($0.rawValue)) && !library.isFavorite(.builtIn($1.rawValue)) }
        return LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(presets) { preset in presetCard(preset, library: library) }
            if savesLast { saveCard }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.textStyles")
    }

    private var saveCard: some View {
        PanelSaveStyleCard {
            naming = StyleNameRequest(purpose: .save, name: viewModel.overlays.suggestedTextStyleName)
        }
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
        PanelNote(text: String(localized: "The effect makes its own light and shadow. Pick a style without it to use a background or an outline."))
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
