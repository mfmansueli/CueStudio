//
//  FakeFaceFinder.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
@testable import Cue_Studio

/// Finds the faces a test gives, in every picture; the first time, after what `hook` says the creator does meanwhile.
nonisolated struct FakeFaceFinder: FaceFinding {
    var boxes: [CGRect] = []
    var hook: FakeFaceFinderHook?

    @concurrent
    func face(in url: URL, isVideo: Bool, at time: TimeInterval) async -> (box: CGRect?, size: CGSize)? {
        if let meanwhile = hook?.take() { await meanwhile() }
        return (boxes.first, CGSize(width: 360, height: 640))
    }

    @concurrent
    func faces(in url: URL, isVideo: Bool, at time: TimeInterval) async -> [CGRect]? {
        if let meanwhile = hook?.take() { await meanwhile() }
        return boxes
    }
}
