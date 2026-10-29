//
//  EditorPanelView.swift
//  Cue Studio
//

import SwiftUI

/// The open panel.
struct EditorPanelView: View {
    let viewModel: QuickEditViewModel
    let panel: EditorPanel

    var body: some View {
        switch panel {
        case .speed: SpeedPanel(viewModel: viewModel)
        case .zoom: ZoomPanel(viewModel: viewModel)
        case .stabilize: StabilizePanel(viewModel: viewModel)
        case .clipCrop: ClipCropPanel(viewModel: viewModel)
        case .clipAnimation: ClipAnimationPanel(viewModel: viewModel)
        case .volume: VolumePanel(viewModel: viewModel)
        case .transition: TransitionPanel(viewModel: viewModel)
        case .voice: VoicePanel(viewModel: viewModel)
        case .pauses: PausesPanel(viewModel: viewModel)
        case .adjust: AdjustPanel(viewModel: viewModel)
        case .skin: SkinPanel(viewModel: viewModel)
        case .filters: FiltersPanel(viewModel: viewModel)
        case .crop: CropPanel(viewModel: viewModel)
        case .background: BackgroundPanel(viewModel: viewModel)
        case .captions: CaptionsPanel(viewModel: viewModel)
        case .autoCaptions: AutoCaptionsPanel(viewModel: viewModel)
        case .captionStyle: CaptionStylePanel(viewModel: viewModel)
        case .textStyle: TextStylePanel(viewModel: viewModel)
        case .voiceOver: VoiceOverPanel(viewModel: viewModel)
        case .beats: BeatsPanel(viewModel: viewModel)
        case .voiceEffects: VoiceEffectsPanel(viewModel: viewModel)
        case .media: MediaPanel(viewModel: viewModel)
        case .mask: MaskPanel(viewModel: viewModel)
        case .motion: MediaMotionPanel(viewModel: viewModel)
        case .blur: BlurPanel(viewModel: viewModel)
        case .smart: SmartPanel(viewModel: viewModel)
        }
    }
}
