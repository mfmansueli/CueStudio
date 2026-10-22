//
//  EditedComposition+EyeContact.swift
//  Cue Studio
//

import Foundation

/// Eye Contact's decisions for the recordings an edit plays, by recording (nil: the take). An export first makes what's still
/// missing of their analyses, so it never comes out with the eyes corrected in one part and not another; the preview draws with
/// what's ready and is drawn again as more is (`EyeContactAnalysisService`).
nonisolated extension EditedComposition {
    /// The decisions for every recording the edit plays, when it corrects the eyes; with `analyzesMissing`, the parts of their
    /// analyses not made yet (or of another version or file) are made now, off the main thread, reporting how far (0 to 1, all
    /// recordings together) to `progress`. A recording that can't be read is drawn as filmed. Making one stops when the build is
    /// dropped (`CancellationError`) or the iPhone gets hot (`BuildError.tooWarm`: what's done is kept and goes on next time).
    static func eyeContactTracks(
        take: URL, edit: TakeEdit, analyzesMissing: Bool, analyzer: EyeContactAnalyzing = EyeContactAnalyzer(),
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [UUID?: EyeContactTrack] {
        guard let settings = edit.eyeContact else { return [:] }
        let recordings = playedRecordings(take: take, edit: edit)
        var tracks: [UUID?: EyeContactTrack] = [:]
        for (position, (id, url)) in recordings.enumerated() {
            if analyzesMissing, EyeContactAnalysisStore.load(forRecording: url)?.isComplete != true {
                let previous = EyeContactAnalysisStore.load(forRecording: url)
                let share = 1 / Double(recordings.count)
                let made: EyeContactAnalysis
                do {
                    made = try await analyzer.analyze(
                        videoAt: url, continuing: previous, focus: nil,
                        shouldStop: { Task.isCancelled || MotionAnalysisPause.reason(isActive: true, thermal: thermalState()) == .heat },
                        checkpoint: { analysis in
                            EyeContactAnalysisStore.save(analysis, forRecording: url)
                            progress?((Double(position) + analysis.progress) * share)
                        }
                    )
                } catch {
                    try Task.checkCancellation()
                    continue
                }
                EyeContactAnalysisStore.save(made, forRecording: url)
                guard made.isComplete else {
                    try Task.checkCancellation()
                    throw BuildError.tooWarm
                }
            }
            if let plan = EyeContactAnalysisStore.plan(forRecording: url) {
                tracks[id] = EyeContactTrack(plan: plan, strength: settings.strength)
            }
        }
        progress?(1)
        return tracks
    }

    /// The take's recording (when a clip plays it) and the montage's other recordings the edit plays, by id (nil: the take).
    static func playedRecordings(take: URL, edit: TakeEdit) -> [(id: UUID?, url: URL)] {
        var recordings: [(id: UUID?, url: URL)] = []
        if edit.timeline.segments.contains(where: { $0.sourceID == nil }) { recordings.append((nil, take)) }
        for clip in edit.playedSources { recordings.append((clip.id, EditMediaFiles.url(for: clip.fileName))) }
        return recordings
    }
}
