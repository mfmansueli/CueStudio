//
//  LookViewModel+MotionAnalysis.swift
//  Cue Studio
//

import Foundation

/// The recordings' motion analysis (`MotionAnalysisService`): asked for every recording the edit plays when Format or Stabilize
/// opens (so Follow face and Stabilize are ready by the time they're turned on), when the editor opens on an edit that uses
/// them, and for each new one it plays while it uses them (a clip reversed or replaced, a new clip of a montage); the preview is
/// drawn again when one is ready.
extension LookViewModel {
    /// The take's recording and the other recordings the edit plays.
    var playedRecordingURLs: [URL] {
        var urls: [URL] = []
        if edit.timeline.segments.contains(where: { $0.sourceID == nil }) { urls.append(session.videoURL) }
        urls += edit.playedSources.map { EditMediaFiles.url(for: $0.fileName) }
        return urls
    }

    /// Asks for the analysis of every recording the edit plays that doesn't have one.
    func requestMotionAnalysis() {
        let urls = playedRecordingURLs
        motionRequestedURLs = urls
        motion?.request(urls)
    }

    /// The edit changed: while Follow face or Stabilize is on, a recording it plays now that wasn't asked for is (so the
    /// preview draws it as the export will).
    func requestMotionAnalysisIfNeeded() {
        guard motion != nil, EditedComposition.usesMotion(edit) else { return }
        let urls = playedRecordingURLs
        guard !Set(urls).isSubset(of: motionRequestedURLs) else { return }
        requestMotionAnalysis()
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
        MotionAnalysisStore.complete(forRecording: session.videoURL)
    }
}
