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
    /// another version) are made now, off the main thread. A recording that can't be analyzed is drawn without. Making one
    /// stops when the build is dropped (`CancellationError`) or the iPhone gets hot (`BuildError.tooWarm`: what's done is kept
    /// and goes on next time), rather than heating it further or exporting something other than what the creator asked for.
    static func motionAnalyses(
        take: URL, edit: TakeEdit, analyzesMissing: Bool, analyzer: MotionAnalyzing = MotionAnalyzer(),
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }
    ) async throws -> [UUID?: MotionAnalysis] {
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
                let made: MotionAnalysis
                do {
                    made = try await analyzer.analyze(
                        videoAt: url, continuing: previous,
                        shouldStop: { Task.isCancelled || MotionAnalysisPause.reason(isActive: true, thermal: thermalState()) == .heat },
                        checkpoint: { MotionAnalysisStore.save($0, forRecording: url) }
                    )
                } catch {
                    try Task.checkCancellation()
                    continue
                }
                MotionAnalysisStore.save(made, forRecording: url)
                guard made.isComplete else {
                    try Task.checkCancellation()
                    throw BuildError.tooWarm
                }
                analyses[id] = made
            }
        }
        return analyses
    }

    /// The sound of each curved clip of `segments`, rendered along its curve (with the voice's pitch kept or not, as the clip
    /// says), by clip, with the assets to keep while the composition is built. A clip whose sound can't be rendered is stretched
    /// in steps. Throws `CancellationError` when the build is dropped meanwhile.
    static func curveSounds(
        for segments: [EditSegment], sound: (UUID?) -> AVAssetTrack?
    ) async throws -> (assets: [AVURLAsset], tracks: [UUID: AVAssetTrack]) {
        var assets: [AVURLAsset] = []
        var tracks: [UUID: AVAssetTrack] = [:]
        for segment in segments where segment.speedCurve != nil {
            // The file the sound is read from: the recording, or Studio Voice's treatment of it.
            guard let curve = segment.speedCurve, let track = sound(segment.sourceID), let file = (track.asset as? AVURLAsset)?.url else { continue }
            let url: URL
            do {
                url = try await CurveSoundRenderer.render(
                    file: file, trackID: track.trackID, span: segment.span, curve: curve, keepsPitch: segment.keepsPitch,
                    clip: segment.id.uuidString
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
            let asset = AVURLAsset(url: url)
            if let rendered = try? await asset.loadTracks(withMediaType: .audio).first {
                assets.append(asset)
                tracks[segment.id] = rendered
            }
        }
        return (assets, tracks)
    }

    /// Stabilize's path for the recording `id` plays (nil: the take), worked out once per recording and level while its
    /// analysis doesn't change (`MotionAnalysisStore`); from `analysis` itself when it isn't kept (it couldn't be saved).
    static func steadyPath(
        for id: UUID?, of edit: TakeEdit, take: URL, analysis: MotionAnalysis, level: StabilizationLevel
    ) -> StabilizationPath? {
        let url = id.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? take
        guard MotionAnalysisStore.complete(forRecording: url) != nil else { return StabilizationPath.make(analysis, level: level) }
        return MotionAnalysisStore.stabilizationPath(forRecording: url, level: level)
    }

    /// Follow face's path for a recording cropped to `crop` (Core Image coordinates) of an upright frame `size`; nil without
    /// Follow face, room to move, an analysis or a face.
    static func followPath(for edit: TakeEdit, analysis: MotionAnalysis?, crop: CGRect, size: CGSize) -> FaceFollowPath? {
        guard let follow = edit.faceFollow, edit.cropFit == .fill, let analysis, size.width > 0, size.height > 0 else { return nil }
        return FaceFollowPath.make(analysis, cropWidth: crop.width / size.width, cropHeight: crop.height / size.height, pace: follow.pace)
    }
}
