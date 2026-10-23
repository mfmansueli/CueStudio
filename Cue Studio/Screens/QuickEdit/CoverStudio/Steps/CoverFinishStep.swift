//
//  CoverFinishStep.swift
//  Cue Studio
//

import SwiftUI

/// Finish: what is done to the picture (Clean, Text behind me, Outline me, Dim, Blur) and how strongly; when no person is found,
/// the two that need one say so instead of doing nothing. Then "My cover style": save this look for the next covers, or put the
/// saved one on this cover.
struct CoverFinishStep: View {
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
                            glyph: effect.glyph, glyphFont: .system(size: 18, weight: .heavy, design: .monospaced), title: effect.label,
                            caption: needsPerson ? String(localized: "No person found") : effect.purpose,
                            captionTint: needsPerson ? Palette.warnText : Palette.ink2,
                            isOn: viewModel.composition.effect == effect, width: 98, identifier: "cover.effect.\(effect.rawValue)"
                        ) { viewModel.setEffect(effect) }
                    }
                }
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
            VStack(alignment: .leading, spacing: 8) {
                PanelRowLabel(label: String(localized: "My cover style"), detail: String(localized: "Look only: never the words or the picture."))
                HStack(spacing: 8) {
                    PanelButton(label: String(localized: "Save as my style"), systemImage: "square.and.arrow.down", identifier: "cover.saveStyle") {
                        viewModel.saveMyStyle()
                    }
                    if viewModel.myStyle != nil {
                        PanelButton(label: String(localized: "Use my style"), systemImage: "paintbrush", identifier: "cover.applyStyle") {
                            viewModel.applyMyStyle()
                        }
                    }
                }
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
