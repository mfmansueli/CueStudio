//
//  MediaMotionPanel.swift
//  Cue Studio
//

import SwiftUI

/// Motion for the picked photo or video over the take, straight from its toolbar (as a text has it): a ready-made entrance
/// or exit, Track, and keyframes with when it starts and ends (`MotionKeyframeControls`).
struct MediaMotionPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .motion) {
            MotionKeyframeControls(viewModel: viewModel)
        }
    }
}
