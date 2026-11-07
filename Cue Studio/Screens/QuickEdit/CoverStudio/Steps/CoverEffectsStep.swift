//
//  CoverEffectsStep.swift
//  Cue Studio
//

import SwiftUI

/// Effects, the last step: what is done to the picture (Clean, Text behind me, Outline me, Dim, Blur) and how strongly; when no
/// person is found, the two that need one say so instead of doing nothing. Then Remove cover, when the video had one. Saving the
/// look as a style is in Template, as the last card of the creator's styles.
struct CoverEffectsStep: View {
    let viewModel: CoverStudioViewModel
    /// Remove cover: asked, then done.
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(CoverEffect.allCases) { effect in
                        let needsPerson = effect.needsPersonMask && viewModel.personFound == false
                        PanelGlyphTile(
                            glyph: effect.glyph, glyphFont: .editorGlyph(EditorGlyph.tool, weight: .heavy, design: .monospaced), title: effect.label,
                            caption: needsPerson ? String(localized: "No person found") : effect.purpose,
                            captionTint: needsPerson ? Palette.warnText : Palette.ink2,
                            isOn: viewModel.composition.effect == effect, width: 98, identifier: "cover.effect.\(effect.rawValue)"
                        ) { viewModel.setEffect(effect) }
                    }
                }
                // One height for the row: a tile whose name or caption takes more lines makes them all that tall.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            effectNote
            if viewModel.composition.effect == .dim || viewModel.composition.effect == .blur {
                PanelSlider(
                    label: String(localized: "Strength"), value: viewModel.composition.effectAmount * 100, range: 0...100, step: 5,
                    defaultValue: 50, format: .percent, identifier: "cover.effectAmount",
                    onChange: { viewModel.setEffectAmount($0 / 100) },
                    onEditingChanged: { editing in if editing { viewModel.beginGesture() } else { viewModel.endGesture() } }
                )
            }
            if viewModel.hadCover {
                PanelButton(
                    label: String(localized: "Remove cover"), systemImage: "trash", isDestructive: true, identifier: "cover.remove", action: onRemove
                )
            }
        }
    }

    @ViewBuilder
    private var effectNote: some View {
        let effect = viewModel.composition.effect
        if effect.needsPersonMask {
            switch viewModel.personFound {
            case false?:
                PanelNote(text: String(localized: "Cue couldn't find a person in this picture, so nothing goes in front of the words. Try a frame where you're clearly visible."))
            case nil:
                PanelNote(text: String(localized: "Finding you in the picture…"))
            case true?:
                PanelNote(text: String(localized: "Done on your iPhone. Move the title behind you to see it."))
            }
        }
    }
}
