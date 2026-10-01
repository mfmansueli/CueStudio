//
//  ExportOptions.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

nonisolated struct ExportOptions: Hashable, Sendable {
    /// Output frame; the recording is cropped to it.
    var aspect: AspectRatio
    /// Quick edit's recipe; nil exports the recording as it was filmed.
    var edit: TakeEdit?
    /// "Burn in captions" when sharing, using the edit's captions.
    var burnsInCaptions = false
    /// Short side of the output in pixels (720, 1080 or 2160); nil keeps the recording's.
    var shortSide: CGFloat?
    /// Frames per second of the output; nil keeps the recording's.
    var frameRate: Double?

    /// Anything beyond a crop goes through the Quick edit renderer.
    var needsEditRenderer: Bool {
        edit != nil || burnsInCaptions || shortSide != nil || frameRate != nil
    }
}
