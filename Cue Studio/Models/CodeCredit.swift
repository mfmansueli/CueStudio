//
//  CodeCredit.swift
//  Cue Studio
//

import Foundation

/// Work by others that Cue's own code adapts, for Settings › Acknowledgements. Cue ships no third-party library: this is
/// where an idea, a formula or a model's weights came from, with the license that asks for its notice to travel with the app.
nonisolated struct CodeCredit: Identifiable, Hashable, Sendable {
    let name: String
    let license: String
    let copyright: String
    /// The license's text file in the bundle (without ".txt").
    let licenseFile: String

    var id: String { name }

    var licenseText: String {
        Bundle.main.url(forResource: licenseFile, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    static let all: [CodeCredit] = [
        CodeCredit(
            name: "GL Transitions", license: "MIT License", copyright: "Copyright (c) 2017-present gl-transitions contributors",
            licenseFile: "gl-transitions-MIT"
        ),
        // Eye Contact's face landmarks: MediaPipe's trained weights, converted for Core ML (`tools/eyecontact/landmarks.py`).
        CodeCredit(
            name: "MediaPipe Face Mesh (Eye Contact)", license: "Apache License 2.0", copyright: "Copyright 2023 The MediaPipe Authors",
            licenseFile: "mediapipe-Apache-2.0"
        ),
        // Eye Contact's rules (when to correct, how fast, how to blend) follow how this open host of NVIDIA Maxine's eye contact runs
        // it; its code was read and the rules rewritten, none of it is in Cue.
        CodeCredit(
            name: "Locked Gaze (Eye Contact)", license: "MIT License", copyright: "Copyright (c) 2026 albond",
            licenseFile: "locked-gaze-MIT"
        ),
    ]
}
