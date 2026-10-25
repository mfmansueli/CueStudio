//
//  FaceFinding.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Finds the face a split-screen area should be framed on when it's first made (`SplitPlacement.framing(showing:)`).
nonisolated protocol FaceFinding: Sendable {
    /// The largest face in the photo at `url`, or in the video's frame at `time`, as a box on the upright picture (fractions
    /// from its top left), with the picture's upright size; a nil box without a face, nil altogether when it can't be read.
    @concurrent
    func face(in url: URL, isVideo: Bool, at time: TimeInterval) async -> (box: CGRect?, size: CGSize)?
}
