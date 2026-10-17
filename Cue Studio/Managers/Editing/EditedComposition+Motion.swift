//
//  EditedComposition+Motion.swift
//  Cue Studio
//

import AVFoundation
import CoreGraphics
import Foundation

/// The motion analyses an edit draws with (Follow face, stabilization), by recording (nil: the take). An export makes the ones
/// still missing before it starts, so it never comes out different from what the creator asked for; the preview uses the ones
/// ready and is drawn again when another one is (`MotionAnalysisService`).
nonisolated extension EditedComposition {
    /// Whether anything in the edit reads a recording's motion analysis.
    static func usesMotion(_ edit: TakeEdit) -> Bool {
        (edit.faceFollow != nil && edit.cropFit == .fill) || edit.timeline.segments.contains { $0.stabilization != nil }
    }

    /// The analyses of the recordings the edit plays, when it uses them; with `analyzesMissing`, the ones not made yet (or of
    /// another version) are made now. A recording that can't be analyzed is drawn without.
    static func motionAnalyses(take: URL, edit: TakeEdit, analyzesMissing: Bool) async -> [UUID?: MotionAnalysis] {
        guard usesMotion(edit) else { return [:] }
        var recordings: [UUID?: URL] = [:]
        if edit.timeline.segments.contains(where: { $0.sourceID == nil }) { recordings[nil] = take }
        for clip in edit.playedSources { recordings[clip.id] = EditMediaFiles.url(for: clip.fileName) }
        var analyses: [UUID?: MotionAnalysis] = [:]
        for (id, url) in recordings {
            if let ready = MotionAnalysisStore.complete(forRecording: url) {
                analyses[id] = ready
            } else if analyzesMissing {
                let previous = MotionAnalysisStore.load(forRecording: url)
                guard let made = try? await MotionAnalyzer().analyze(videoAt: url, continuing: previous, shouldStop: { false }, checkpoint: { _ in })
                else { continue }
                MotionAnalysisStore.save(made, forRecording: url)
                analyses[id] = made
            }
        }
        return analyses
    }

    /// The sound of each curved clip, rendered along its curve (with the voice's pitch kept or not, as the clip says), by clip,
    /// with the assets to keep while the composition is built. A clip whose sound can't be rendered is stretched in steps.
    static func curveSounds(
        for timeline: EditTimeline, take: URL, sound: (UUID?) -> AVAssetTrack?
    ) async -> (assets: [AVURLAsset], tracks: [UUID: AVAssetTrack]) {
        var assets: [AVURLAsset] = []
        var tracks: [UUID: AVAssetTrack] = [:]
        for segment in timeline.segments where segment.speedCurve != nil {
            guard let curve = segment.speedCurve, let track = sound(segment.sourceID),
                  let url = try? await CurveSoundRenderer.render(
                      track, span: segment.span, curve: curve, keepsPitch: segment.keepsPitch,
                      key: (segment.sourceID?.uuidString ?? take.lastPathComponent) + "\(track.trackID)"
                  ) else { continue }
            let asset = AVURLAsset(url: url)
            if let rendered = try? await asset.loadTracks(withMediaType: .audio).first {
                assets.append(asset)
                tracks[segment.id] = rendered
            }
        }
        return (assets, tracks)
    }

    /// Follow face's path for a recording cropped to `crop` (Core Image coordinates) of an upright frame `size`; nil without
    /// Follow face, room to move, an analysis or a face.
    static func followPath(for edit: TakeEdit, analysis: MotionAnalysis?, crop: CGRect, size: CGSize) -> FaceFollowPath? {
        guard let follow = edit.faceFollow, edit.cropFit == .fill, let analysis, size.width > 0, size.height > 0 else { return nil }
        return FaceFollowPath.make(analysis, cropWidth: crop.width / size.width, cropHeight: crop.height / size.height, pace: follow.pace)
    }
}
