//
//  FakeFaceDetector.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
@testable import Cue_Studio

/// Finds the faces a test says are in the frame, and counts how often it was asked. A drawing is not a face to Vision, so tests give the faces.
final class FakeFaceDetector: FaceDetecting, @unchecked Sendable {
    private let lock = NSLock()
    private var found: [FaceLandmarks]
    private var asked = 0

    init(faces: [FaceLandmarks] = []) { found = faces }

    /// What the next detections find.
    var faces: [FaceLandmarks] {
        get { lock.withLock { found } }
        set { lock.withLock { found = newValue } }
    }

    /// How many times it was asked.
    var calls: Int { lock.withLock { asked } }

    func faces(in image: CIImage) -> [FaceLandmarks] {
        lock.withLock {
            asked += 1
            return found
        }
    }
}
