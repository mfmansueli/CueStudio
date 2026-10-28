//
//  CaptionStylePanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Caption style, always for every line, and the one place captions are styled, in four tabs: Styles (the catalogue and the
/// creator's saved styles, filtered: picking one changes the look and the motion, never where the captions sit), Format (how
/// the lines are cut, where they sit, how big, wide and aligned: what stays when the style changes), Animation (how they come
/// in and go out, show and light the word being said) and Adjust (the look's details, over any style). The video stays in
/// sight, each pick plays the current line ("Preview" in the header plays it again), and the panel expands like Text style.
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
            // Styles comes back where it was left; the other tabs start at their top.
            keptOffset: tab == .styles ? catalogOffset : nil,
            play: viewModel.captions.editedCaptionLines.isEmpty ? nil : PanelPlay(action: viewModel.captions.previewCurrentCaptionLine)
        ) {
            PanelTabs(tabs: EditorPanelTab.captionStyle, selection: tab) { viewModel.panelTab = $0 }
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

    private var catalogOffset: Binding<CGFloat> {
        Binding(get: { viewModel.captions.captionCatalogOffset }, set: { viewModel.captions.captionCatalogOffset = $0 })
    }

    /// Reset puts the style the captions are in back whole: its look, motion, size and place (a copied look goes too).
    private var resetAction: (() -> Void)? {
        guard viewModel.edit.captionCollection != nil else { return nil }
        return { viewModel.captions.resetCaptionTheme() }
    }
}
