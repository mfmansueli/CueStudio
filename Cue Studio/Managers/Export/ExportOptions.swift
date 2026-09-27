//
//  ExportOptions.swift
//  Cue Studio
//

import Foundation

nonisolated struct ExportOptions: Hashable, Sendable {
    /// Output frame; the recording is center-cropped to it.
    var aspect: AspectRatio
    /// Free-plan exports past the limit carry a "Made with Cue" badge.
    var watermark: Bool
}
