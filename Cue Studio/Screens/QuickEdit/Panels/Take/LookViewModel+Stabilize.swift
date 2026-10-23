//
//  LookViewModel+Stabilize.swift
//  Cue Studio
//

import Foundation

/// Stabilize (this clip): Off, Gentle, Standard or Strong, and "Use on every clip". The clip's recording is analyzed for its
/// shake (`MotionAnalysisService`); until it is, the panel says how far that is and the clip plays as filmed. Each change is an
/// undo step.
extension LookViewModel {
    func setStabilization(_ level: StabilizationLevel?) {
        guard targetClip?.stabilization != level else { return }
        updateClip { $0.stabilization = level }
        if level != nil { requestMotionAnalysis() }
    }

    /// "Use on every clip": the picked clip's level on all of them, as one step.
    func useStabilizationOnEveryClip() {
        guard let level = targetClip?.stabilization else { return }
        var timeline = edit.timeline
        guard timeline.segments.contains(where: { $0.stabilization != level }) else {
            toast.show(String(localized: "Every clip already has it"))
            return
        }
        for var segment in timeline.segments {
            segment.stabilization = level
            _ = timeline.replaceSegment(segment)
        }
        commit(timeline)
        toast.show(String(localized: "Stabilize on every clip"))
    }

    /// How much the picked clip is zoomed in to hide the edges ("Zoomed in 6%"), once its recording is analyzed.
    var stabilizationZoomNote: String? {
        guard let clip = targetClip, let level = clip.stabilization else { return nil }
        let url = clip.sourceID.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
        // Both read from memory while the analysis file doesn't change (the panel asks on every redraw).
        guard MotionAnalysisStore.complete(forRecording: url) != nil else { return nil }
        guard let path = MotionAnalysisStore.stabilizationPath(forRecording: url, level: level) else {
            return String(localized: "No shake found in this clip")
        }
        let percent = Int(((path.zoom - 1) * 100).rounded())
        return percent < 1 ? String(localized: "Steady already · no zoom needed") : String(localized: "Zoomed in \(percent)% to hide the edges")
    }

    /// The analysis line while the picked clip's recording isn't ready.
    var stabilizationNote: String? {
        guard targetClip?.stabilization != nil else { return nil }
        return MotionAnalysisNote.text(for: motionAnalysisStatus, purpose: .shake) ?? stabilizationZoomNote
    }
}
