//
//  FaceFollowLimit.swift
//  Cue Studio
//

import Foundation

/// What Follow face can't promise over a recording, read from its analysis, for an honest line under the switch (F16). The framing never
/// changes because of it: the path keeps to one face (`FaceFollowPath`) and holds still where nobody is found. Vision's confidence isn't
/// kept in the analysis (a face under 0.5 is never stored), so a weak detection shows as moments without a face.
nonisolated enum FaceFollowLimit: Equatable, Sendable {
    /// Nobody in the whole recording.
    case noFace
    /// Two faces or more in a good part of it: the frame follows one.
    case severalFaces
    /// A face (or a person) in only part of it: where it's lost, the frame holds still.
    case partlyFound

    /// Share of the moments with somebody in which two faces or more show, from which the line says so.
    static let severalFacesShare = 0.25
    /// Share of the moments with somebody (a face or a body) under which the face counts as found in part of the video only.
    static let foundShare = 0.6

    /// The limit `analysis` shows, the strongest first; nil when a single face is found nearly all the time.
    static func of(_ analysis: MotionAnalysis) -> FaceFollowLimit? {
        let samples = analysis.subjects
        let found = samples.filter { !$0.faces.isEmpty || !$0.bodies.isEmpty }
        guard !found.isEmpty else { return .noFace }
        let several = found.filter { $0.faces.count > 1 }.count
        if Double(several) / Double(found.count) >= severalFacesShare { return .severalFaces }
        if Double(found.count) / Double(samples.count) < foundShare { return .partlyFound }
        return nil
    }

    var note: String {
        switch self {
        case .noFace: String(localized: "No face found in this video")
        case .severalFaces: String(localized: "More than one face in this video · the frame follows one")
        case .partlyFound: String(localized: "Your face is found in part of the video · the frame holds still where it’s lost")
        }
    }
}
