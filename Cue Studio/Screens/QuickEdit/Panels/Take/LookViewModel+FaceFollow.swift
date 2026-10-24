//
//  LookViewModel+FaceFollow.swift
//  Cue Studio
//

import Foundation

/// Format › Follow face: a Fill crop moves with the creator's face over the whole video, at a pace (Calm, Natural, Quick). It
/// needs room: a format narrower or wider than the recording, in Fill. Each change is an undo step; moving the crop by hand
/// turns it off.
extension LookViewModel {
    /// The recording's upright width over height: its analysis has it, or the file read when the editor opened; recordings are
    /// filmed upright at 9:16.
    private var recordingAspect: Double {
        if let aspect = takeMotionAnalysis?.aspect { return aspect }
        if let size = recordingUprightSize, size.height > 0 { return size.width / size.height }
        return 9.0 / 16.0
    }

    /// Whether the crop has room to follow a face: Fill, and a format other than the recording's (or a montage, whose other
    /// recordings may be wider).
    var canFollowFace: Bool {
        guard edit.cropFit == .fill else { return false }
        return abs(edit.aspect.widthOverHeight - recordingAspect) > 0.01 || !edit.playedSources.isEmpty
    }

    var followsFace: Bool { edit.faceFollow != nil && canFollowFace }

    func setFollowsFace(_ follows: Bool) {
        guard follows != (edit.faceFollow != nil) else { return }
        changeEdit { $0.faceFollow = follows ? FaceFollow() : nil }
        if follows { requestMotionAnalysis() }
    }

    func setFollowPace(_ pace: FollowPace) {
        guard edit.faceFollow != nil, edit.faceFollow?.pace != pace else { return }
        changeEdit { $0.faceFollow = FaceFollow(pace: pace) }
    }

    /// A finger starts moving the frame on the preview: the whole drag is one undo step (`moveCrop(to:)`, `endChange`), and
    /// following the face would undo it, so it stops (once, with a word).
    func beginCropMove() {
        beginChange()
        guard edit.faceFollow != nil else { return }
        changeEdit { $0.faceFollow = nil }
        toast.show(String(localized: "Follow face is off · You moved the frame"))
    }

    /// Where the dragged frame sits, -1 (top or left) to 1 (bottom or right).
    func moveCrop(to offset: Double) {
        changeEdit { $0.cropOffset = min(1, max(-1, offset)) }
    }

    /// The line under Follow face: why it can't, how far the analysis is, or that no face was found.
    var faceFollowNote: String? {
        guard canFollowFace else {
            return edit.cropFit == .fit
                ? String(localized: "Follow face works with Fill")
                : String(localized: "Pick 4:5, 1:1 or 16:9 to follow your face")
        }
        guard edit.faceFollow != nil else { return nil }
        if let pending = MotionAnalysisNote.text(for: motionAnalysisStatus, purpose: .face) { return pending }
        if let analysis = takeMotionAnalysis, !analysis.subjects.contains(where: { !$0.faces.isEmpty || !$0.bodies.isEmpty }) {
            return String(localized: "No face found in this video")
        }
        return nil
    }
}
