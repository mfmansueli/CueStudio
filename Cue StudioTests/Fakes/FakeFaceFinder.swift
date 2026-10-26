//
//  FakeFaceFinder.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
@testable import Cue_Studio

/// Finds the faces a test gives, in every picture.
nonisolated struct FakeFaceFinder: FaceFinding {
    var boxes: [CGRect] = []

    @concurrent
    func face(in url: URL, isVideo: Bool, at time: TimeInterval) async -> (box: CGRect?, size: CGSize)? {
        (boxes.first, CGSize(width: 360, height: 640))
    }

    @concurrent
    func faces(in url: URL, isVideo: Bool, at time: TimeInterval) async -> [CGRect]? {
        boxes
    }
}
