//
//  CaptionAnimationTab.swift
//  Cue Studio
//

import SwiftUI

/// Caption style › Animation, three choices apart: how the captions come in and go out, whether they show whole or word by
/// word, and how the word being said stands out (with its color). Tapping one plays the current line with it; "Back to
/// <style>'s look" brings the style back whole. Captions from before the collection keep the one list of reveals they had.
struct CaptionAnimationTab: View {
    @Bindable var viewModel: QuickEditViewModel

    @ScaledMetric(relativeTo: .body) private var swatchDiameter: CGFloat = 34

    private var captions: CaptionsViewModel { viewModel.captions }

    var body: some View {
        if viewModel.edit.captionCollection != nil {
            let motion = captions.captionMotion
            group(String(localized: "In and out")) {
                PanelTiles(
                    options: CaptionEntry.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage) },
                    selection: motion.entry, identifier: "edit.captionEntry", onSelect: captions.setCaptionEntry
                )
            }
            group(String(localized: "Reveal")) {
                PanelTiles(
                    options: CaptionReveal.allCases.map { reveal in
                        PanelOption(reveal, reveal.label, systemImage: reveal.systemImage, isEnabled: reveal == .line || !captions.captionRevealIsMoot)
                    },
                    selection: motion.reveal, identifier: "edit.captionRevealMode", onSelect: captions.setCaptionRevealMode
                )
                if captions.captionRevealIsMoot {
                    PanelNote(text: String(localized: "One word already shows the words one at a time."))
                }
            }
            group(String(localized: "Word being said")) {
                PanelTiles(
                    options: CaptionSpokenHighlight.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage) },
                    selection: motion.spoken, identifier: "edit.captionSpoken", onSelect: captions.setCaptionSpokenHighlight
                )
            }
            if motion.spoken != .none, let accent = captions.captionAccent {
                PanelSwatches(
                    label: String(localized: "Highlight color"), colors: OverlayColor.palette, selection: accent, diameter: swatchDiameter,
                    reset: viewModel.edit.captionCollection?.accent == nil ? nil : (String(localized: "Style's"), { captions.resetCaptionAccent() }),
                    identifier: "edit.captionAccent"
                ) { captions.setCaptionAccent($0) }
                if !captions.captionHighlightStandsOut {
                    PanelNote(text: String(localized: "The word being said is the same color as the others: pick another highlight color."), tint: Palette.warnText)
                }
            }
            if motion.followsWords, captions.linesWithoutWordTiming > 0 {
                PanelNote(text: String(localized: "\(captions.linesWithoutWordTiming) lines follow the voice approximately."))
            }
            PanelNote(text: String(localized: "Tap a choice to preview it on the current line."))
            // The way back to the style whole is here too: a motion changed here makes the captions this video's own look.
            if captions.changedCaptionLookCount > 0, let theme = viewModel.edit.captionCollection?.theme {
                PanelButton(
                    label: String(localized: "Back to \(theme.label)'s look"), systemImage: "arrow.uturn.backward",
                    identifier: "edit.captionAnimation.reset", action: captions.resetCaptionLook
                )
            }
        } else {
            PanelTiles(
                options: [
                    PanelOption(CaptionAnimation.line, CaptionAnimation.line.label, systemImage: "text.alignleft"),
                    PanelOption(CaptionAnimation.fade, CaptionAnimation.fade.label, systemImage: "circle.lefthalf.filled"),
                    PanelOption(CaptionAnimation.groups, CaptionAnimation.groups.label, systemImage: "text.word.spacing"),
                    PanelOption(CaptionAnimation.highlight, CaptionAnimation.highlight.label, systemImage: "highlighter"),
                    PanelOption(CaptionAnimation.box, CaptionAnimation.box.label, systemImage: "character.textbox"),
                ],
                selection: captions.captionReveal, identifier: "edit.captionReveal"
            ) { captions.pickCaptionReveal($0) }
            PanelNote(text: String(localized: "Tap a style to preview it on the current line."))
        }
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: title)
            content()
        }
    }
}
