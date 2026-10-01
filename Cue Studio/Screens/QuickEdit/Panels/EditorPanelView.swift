//
//  EditorPanelView.swift
//  Cue Studio
//

import SwiftUI

/// The open panel, in its frame (`EditorPanelContainer`).
struct EditorPanelView: View {
    let viewModel: QuickEditViewModel
    let panel: EditorPanel

    var body: some View {
        EditorPanelContainer(
            title: viewModel.panelTitle(panel),
            subtitle: viewModel.panelSubtitle(panel),
            onApply: viewModel.closePanel
        ) {
            content
        }
        .accessibilityIdentifier("edit.panel.\(panel.rawValue)")
    }

    @ViewBuilder
    private var content: some View {
        switch panel {
        case .speed, .zoom: SpeedToolView(viewModel: viewModel)
        case .volume, .voice: AudioToolView(viewModel: viewModel)
        case .pauses: CleanUpToolView(viewModel: viewModel)
        case .adjust: AdjustToolView(viewModel: viewModel)
        case .filters: FiltersToolView(viewModel: viewModel)
        case .crop: CropToolView(viewModel: viewModel)
        case .background: BackgroundToolView(viewModel: viewModel)
        case .cover: CoverToolView(viewModel: viewModel)
        case .captions, .autoCaptions, .captionStyle: CaptionsToolView(viewModel: viewModel)
        case .textStyle: StyleToolView(viewModel: viewModel)
        case .voiceOver: VoiceOverToolView(viewModel: viewModel)
        case .media: MediaToolView(viewModel: viewModel)
        case .transition: TrimToolView(viewModel: viewModel)
        }
    }
}
