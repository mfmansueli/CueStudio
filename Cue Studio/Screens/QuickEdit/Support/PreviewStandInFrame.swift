//
//  PreviewStandInFrame.swift
//  Cue Studio
//

import SwiftUI

/// UI tests (`-uiTestPreviewFrame white|black`): the editor's preview shows a plain white or black frame under everything laid on
/// the video, in place of the video the Simulator can't play, so a capture measures what the editor draws over a light video and a
/// dark one (the safe zone guide's line and label). Never in a Release build's launch.
nonisolated enum PreviewStandInFrame: String, Sendable {
    case white, black
}

extension PreviewStandInFrame {
    /// The frame's one color: the lightest and the darkest a video can be.
    var color: Color {
        switch self {
        case .white: Color.white
        case .black: Color.black
        }
    }
}

extension EnvironmentValues {
    /// The stand-in for the video on the editor's preview (`PreviewStandInFrame`); nil plays the video.
    @Entry var previewStandInFrame: PreviewStandInFrame?
}
