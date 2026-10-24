//
//  SplitScreenPanel.swift
//  Cue Studio
//

import SwiftUI

/// A support of the split screen, picked: its tabs, Layout (where the two contents go, for the whole video), Framing (how
/// each content sits in its area, the picked area outlined on the preview), Sound (the main video's and the support's) and
/// Part (which part of the support plays and for how long). The preview stays in view to drag and pinch each area.
struct SplitScreenPanel: View {
    @Bindable var viewModel: QuickEditViewModel
    let media: MediaOverlay

    var body: some View {
        let tab = viewModel.overlays.splitTab
        PanelFrame(viewModel: viewModel, panel: .media) {
            PanelTabs(tabs: EditorPanelTab.splitScreen, selection: tab) { viewModel.panelTab = $0 }
        } content: {
            switch tab {
            case .framing: SplitFramingTab(viewModel: viewModel, media: media)
            case .sound: SplitSoundTab(viewModel: viewModel, media: media)
            case .part: SplitPartTab(viewModel: viewModel, media: media)
            default: SplitLayoutTab(viewModel: viewModel, media: media)
            }
        }
        .task { await viewModel.overlays.loadRecordingSizes() }
    }
}
