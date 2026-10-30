//
//  FrameGrid.swift
//  Cue Studio
//

import Foundation

/// The recording's frame rate as Quick edit steps through its frames (`EditorSession.frameRate`): the
/// file's own, read when it opens.
nonisolated struct FrameGrid: Hashable, Sendable {
    /// Frames per second.
    let rate: Double

    /// `rate` from the file; 30 when it can't be read.
    init(rate: Double) {
        self.rate = rate.isFinite && rate >= 1 ? min(rate, 240) : 30
    }
}
