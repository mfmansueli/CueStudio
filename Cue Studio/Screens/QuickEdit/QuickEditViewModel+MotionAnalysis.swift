//
//  QuickEditViewModel+MotionAnalysis.swift
//  Cue Studio
//

import Foundation

/// The recordings' motion analysis (`MotionAnalysisService`): asked for every recording the edit plays when the editor opens
/// (so Follow face and Stabilize are ready by the time they're wanted), and the preview drawn again when one is ready.
extension QuickEditViewModel {
    /// The take's recording and the other recordings the edit plays.
    var playedRecordingURLs: [URL] {
        var urls: [URL] = []
        if edit.timeline.segments.contains(where: { $0.sourceID == nil }) { urls.append(videoURL) }
        urls += edit.playedSources.map { EditMediaFiles.url(for: $0.fileName) }
        return urls
    }

    /// Asks for the analysis of every recording the edit plays that doesn't have one.
    func requestMotionAnalysis() {
        motion?.request(playedRecordingURLs)
    }

    /// An analysis is ready: the preview is drawn again when the edit reads one.
    func motionAnalysisDidChange() {
        guard source == .ready, EditedComposition.usesMotion(playedEdit) else { return }
        player.redraw()
    }

    /// Where the analysis of the recordings the edit plays stands: the one furthest behind (nil when every one is ready or
    /// was never asked for).
    var motionAnalysisStatus: MotionAnalysisStatus? {
        guard let motion else { return nil }
        let statuses = playedRecordingURLs.compactMap { motion.status(of: $0) }
        return statuses.filter { !$0.isReady }.min { $0.progress < $1.progress }
    }

    /// The take's analysis, when it's ready.
    var takeMotionAnalysis: MotionAnalysis? {
        MotionAnalysisStore.complete(forRecording: videoURL)
    }
}
