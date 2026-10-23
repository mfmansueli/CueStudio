//
//  EditRenderPurpose.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What an edit is drawn for (`EditRenderRequest`): the only thing that differs between the editor's preview, a take's review
/// and the export. Everything else is prepared the same way, so what plays is what is written.
nonisolated enum EditRenderPurpose: Hashable, Sendable {
    /// Quick edit's preview: the first and last clips grown to the whole recording, so dragging a handle scrubs real frames
    /// without a rebuild (`EditTimeline.reachable`); motion analyses only when ready; curved clips' sound stretched in steps
    /// while a finger shapes the timing.
    case editorPreview(rendersCurveSound: Bool)
    /// A take's review: the edit as it is.
    case reviewPreview
    /// Writing the video: the captions burned in or not, the quality and the frame rate asked for; motion analyses still
    /// missing are made first.
    case export(burnsInCaptions: Bool, shortSide: CGFloat?, frameRate: Double?)

    var options: EditedComposition.Options {
        switch self {
        case .editorPreview(let rendersCurveSound):
            EditedComposition.Options(
                burnsInCaptions: true, shortSide: 1080, reachesWholeRecording: true, analyzesMissingMotion: false,
                rendersCurveSound: rendersCurveSound
            )
        case .reviewPreview:
            EditedComposition.Options(burnsInCaptions: true, shortSide: 1080, analyzesMissingMotion: false)
        case .export(let burnsInCaptions, let shortSide, let frameRate):
            EditedComposition.Options(burnsInCaptions: burnsInCaptions, shortSide: shortSide, frameRate: frameRate)
        }
    }
}
