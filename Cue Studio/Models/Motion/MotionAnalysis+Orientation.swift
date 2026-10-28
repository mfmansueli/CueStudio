//
//  MotionAnalysis+Orientation.swift
//  Cue Studio
//

import Foundation

extension MotionAnalysis {
    /// The faces and bodies found as a clip turned, mirrored or cropped shows them (`ClipOrientation`), for Follow face on that
    /// clip; what its crop leaves out is dropped.
    nonisolated func oriented(by orientation: ClipOrientation) -> MotionAnalysis {
        var shown = self
        shown.subjects = subjects.map { sample in
            SubjectSample(
                time: sample.time, faces: sample.faces.compactMap(orientation.shownBox), bodies: sample.bodies.compactMap(orientation.shownBox)
            )
        }
        return shown
    }
}
