//
//  FaceFinding.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Finds faces in a picture: the one a split-screen area should be framed on when it's first made
/// (`SplitPlacement.framing(showing:)`), and the ones Blur area offers to hide.
nonisolated protocol FaceFinding: Sendable {
    /// The largest face in the photo at `url`, or in the video's frame at `time`, as a box on the upright picture (fractions
    /// from its top left), with the picture's upright size; a nil box without a face, nil altogether when it can't be read.
    @concurrent
    func face(in url: URL, isVideo: Bool, at time: TimeInterval) async -> (box: CGRect?, size: CGSize)?

    /// Every face in the photo at `url`, or in the video's frame at `time`, largest first (boxes as above); nil when the
    /// picture can't be read.
    @concurrent
    func faces(in url: URL, isVideo: Bool, at time: TimeInterval) async -> [CGRect]?
}
