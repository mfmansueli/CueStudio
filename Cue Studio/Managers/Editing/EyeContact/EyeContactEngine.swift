//
//  EyeContactEngine.swift
//  Cue Studio
//

import Foundation

/// Which Eye Contact this version of Cue draws with: the face mesh (and its weights), the drawing (`EyeRedraw`) and the rules
/// (`EyeGazePlan`'s analysis version). It goes into the export's fingerprint, so a new model or new rules never reuse an export
/// drawn with the old ones.
nonisolated enum EyeContactEngine {
    /// The face mesh's version (`tools/eyecontact/landmarks.py`) and the SHA-256 of its weights.
    static let model = "mediapipe-face-mesh-v2-1"
    static let weights = "03487a67dc497521e067a5df61b79be1f8f5bec14e93d6a7b22959b6cf935ba1"
    /// Bumped when the drawing changes.
    static let drawing = 2

    /// Everything that changes the picture for the same settings.
    static var identity: String {
        "eyes:\(EyeContactSettings.currentEngine):\(model):\(weights.prefix(16)):draw\(drawing):analysis\(EyeContactAnalysis.currentVersion)"
    }
}
