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

    /// A finger starts moving the frame on the preview (only while Format is open): the whole drag is one undo step
    /// (`moveCrop(to:)`, `endPanelChange`), and following the face would undo it, so it stops (once, with a word).
    func beginCropMove() {
        beginPanelChange()
        guard edit.faceFollow != nil else { return }
        changeEdit { $0.faceFollow = nil }
        toast.show(String(localized: "Follow face is off · You moved the frame"))
    }

    /// Where the dragged frame sits, -1 (top or left) to 1 (bottom or right).
    func moveCrop(to offset: Double) {
        changeEdit { $0.cropOffset = min(1, max(-1, offset)) }
    }

    /// The line under Follow face: why it can't, how far the analysis is, or what it can't promise in this video (nobody found, more
    /// than one face, a face found in part of it only: `FaceFollowLimit`). None of these changes the framing; Follow face stays as the
    /// creator set it.
    var faceFollowNote: String? {
        guard canFollowFace else {
            return edit.cropFit == .fit ? String(localized: "Follow face works with Fill") : Self.roomNote(recordingAspect: recordingAspect)
        }
        guard edit.faceFollow != nil else { return nil }
        if let pending = MotionAnalysisNote.text(for: motionAnalysisStatus, purpose: .face) { return pending }
        return playedFaceFollowLimit?.note
    }

    /// What Follow face can't promise over every recording the edit plays, the take's and each imported one's (a horizontal video with
    /// two people in a montage says so: plan §19): more than one face anywhere first, then a face lost in part of the video (or in a
    /// whole recording, when another has one), then nobody at all.
    var playedFaceFollowLimit: FaceFollowLimit? {
        let analyses = playedRecordingURLs.compactMap { MotionAnalysisStore.complete(forRecording: $0) }
        let limits = analyses.map(FaceFollowLimit.of)
        if limits.contains(.severalFaces) { return .severalFaces }
        if limits.contains(.partlyFound) { return .partlyFound }
        guard limits.contains(.noFace) else { return nil }
        return limits.allSatisfy { $0 == .noFace } ? .noFace : .partlyFound
    }

    /// The formats that give a Fill crop room to follow a face in a recording of `recordingAspect` (width over height): every one but
    /// the recording's own shape, which is the one picked when there is no room (bug 11: a 16:9 import was told to pick 16:9).
    static func formatsWithRoom(recordingAspect: Double) -> [AspectRatio] {
        AspectRatio.allCases.filter { abs($0.widthOverHeight - recordingAspect) > 0.01 }
    }

    /// "Pick 4:5, 1:1, or 16:9 to follow your face" from a 9:16 recording; "Pick 9:16, 4:5, or 1:1 …" from a 16:9 one.
    static func roomNote(recordingAspect: Double) -> String {
        let formats = formatsWithRoom(recordingAspect: recordingAspect).map(\.label).formatted(.list(type: .or))
        return String(localized: "Pick \(formats) to follow your face")
    }
}
