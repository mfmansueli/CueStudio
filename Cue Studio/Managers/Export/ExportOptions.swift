//
//  ExportOptions.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

nonisolated struct ExportOptions: Hashable, Sendable {
    /// Output frame; the recording is cropped to it.
    var aspect: AspectRatio
    /// Free-plan exports past the limit carry a "Made with Cue" badge.
    var watermark: Bool
    /// Quick edit's recipe; nil exports the recording as it was filmed.
    var edit: TakeEdit? = nil
    /// "Burn in captions" when sharing, using the edit's captions.
    var burnsInCaptions = false
    /// Short side of the output in pixels (1080 or 2160); nil keeps the recording's.
    var shortSide: CGFloat? = nil

    /// Anything beyond a crop and the badge goes through the Quick edit renderer.
    var needsEditRenderer: Bool {
        edit != nil || burnsInCaptions || shortSide != nil
    }
}
