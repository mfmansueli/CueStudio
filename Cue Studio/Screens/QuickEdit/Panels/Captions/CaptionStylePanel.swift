//
//  CaptionStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Caption style, always for every line, and the one place captions are styled, in four tabs: Styles (the size, then the
/// catalogue and the creator's saved styles, filtered: picking one changes the look and the motion, never where the captions
/// sit; it opens with the style the captions wear in sight), Layout (`.format`: how the lines are cut, one word included, where
/// they sit, how big, wide and aligned: what stays when the style changes), Animation (how they come in and go out, word by
/// word, and which way the word being said stands out) and Custom (`.adjust`: the look's details over any style, the highlight
/// color among them, and the way to the words to emphasize). The video stays in sight, each pick plays the current line
/// ("Preview" in the header plays it again), and the panel expands like Text style.
struct CaptionStylePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frame: UIImage?
    @State private var samples = CaptionCardSamples()
    @State private var naming: StyleNameRequest?

    var body: some View {
        let tab = viewModel.captions.captionStyleTab
        PanelFrame(
            viewModel: viewModel, panel: .captionStyle,
            onReset: resetAction,
            // Styles comes back where it was left (and opens on the style the captions wear); Custom comes back where it was
            // after choosing words to emphasize; the other tabs start at their top.
            keptOffset: keptOffset(tab),
            revealID: revealedSection(tab),
            play: viewModel.captions.editedCaptionLines.isEmpty ? nil : PanelPlay(action: viewModel.captions.previewCurrentCaptionLine)
        ) {
            PanelTabs(tabs: EditorPanelTab.captionStyle, selection: tab) { picked in
                viewModel.captions.restoresCustomOffset = false
                viewModel.panelTab = picked
            }
        } content: {
            switch tab {
            case .format: CaptionFormatTab(viewModel: viewModel)
            case .animation: CaptionAnimationTab(viewModel: viewModel)
            case .adjust: CaptionAdjustTab(viewModel: viewModel)
            default: CaptionStylesTab(viewModel: viewModel, frame: frame, samples: samples, naming: $naming)
            }
        }
        .task {
            guard frame == nil else { return }
            frame = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240)
        }
        .styleNamePrompt($naming) { purpose, name in
            switch purpose {
            case .save: viewModel.captions.saveCaptionStyle(named: name)
            case .rename(let id): viewModel.captions.renameCaptionStyle(id, to: name)
            }
        }
    }

    /// Styles opens with the section of the style the captions wear at its top, when it isn't the first.
    private func revealedSection(_ tab: EditorPanelTab) -> AnyHashable? {
        guard tab == .styles, let section = viewModel.captions.captionRevealedSection(viewModel.captions.captionCatalogFilter) else { return nil }
        return AnyHashable(CaptionStylesTab.sectionID(section))
    }

    private func keptOffset(_ tab: EditorPanelTab) -> Binding<CGFloat>? {
        let captions = viewModel.captions
        switch tab {
        case .styles:
            return Binding(get: { captions.captionCatalogOffset }, set: { captions.captionCatalogOffset = $0 })
        case .adjust:
            return Binding(get: { captions.restoresCustomOffset ? captions.captionCustomOffset : 0 }, set: { captions.captionCustomOffset = $0 })
        default:
            return nil
        }
    }

    /// Reset puts the style the captions are in back whole: its look, motion, size and place (a copied look goes too), and its
    /// toast says so, with Undo (owner, canvas 2 F2: every reset names its reach).
    private var resetAction: (() -> Void)? {
        guard viewModel.edit.captionCollection != nil else { return nil }
        return { viewModel.captions.resetCaptionTheme() }
    }
}
