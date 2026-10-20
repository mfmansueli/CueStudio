//
//  QuickEditViewModel+EyeContact.swift
//  Cue Studio
//

import Foundation

/// ✦ Smart › Eye Contact: on or off and how strong, for the whole edit (every recording it plays; never photos or videos laid over
/// it), each change one undo step (a drag of the slider too). Turning it on asks for the eye analysis of the recordings the edit
/// plays, starting where the playhead is (`EyeContactAnalysisService`); the preview is drawn again as the stretch on screen and then
/// each recording become ready. "Before" shows the eyes as filmed without touching the edit.
extension QuickEditViewModel {
    var eyeContactIsOn: Bool { edit.eyeContact != nil }

    /// The slider's value, 20 to 100.
    var eyeContactStrength: Double {
        (edit.eyeContact?.strength ?? EyeContactSettings.defaultStrength) * 100
    }

    func setEyeContact(_ on: Bool) {
        guard on != eyeContactIsOn else { return }
        comparesEyeContact = false
        changeLook { $0.eyeContact = on ? EyeContactSettings() : nil }
        if !on { eyes?.cancel(playedRecordingURLs) }
    }

    func toggleEyeContact() {
        setEyeContact(!eyeContactIsOn)
    }

    /// From the slider (20 to 100); a drag is one undo step (`beginChange` / `endChange` around it).
    func setEyeContactStrength(_ percent: Double) {
        guard eyeContactIsOn else { return }
        changeLook(key: "eyeContactStrength") { $0.eyeContact?.strength = percent / 100 }
    }

    /// Reset: back to the moderate strength.
    func resetEyeContactStrength() {
        guard eyeContactIsOn else { return }
        changeLook { $0.eyeContact?.strength = EyeContactSettings.defaultStrength }
    }

    /// "Before": shows the eyes as filmed, or the corrected ones again.
    func toggleEyeContactComparison() {
        guard comparesEyeContact || eyeContactIsOn else { return }
        comparesEyeContact.toggle()
    }

    /// Cancel while the eyes are being found: turns Eye Contact off (one undo step) and stops the work; what was found is kept for
    /// next time.
    func cancelEyeContact() {
        setEyeContact(false)
    }

    // MARK: - Analysis

    /// The edit corrects the eyes: asks for the analysis of the recordings it plays when one isn't asked for (never, or since Eye
    /// Contact was turned off), from the playhead.
    func requestEyeContactAnalysisIfNeeded() {
        guard let eyes, eyeContactIsOn else { return }
        eyes.warmUp()
        let urls = playedRecordingURLs
        guard urls.contains(where: { eyes.status(of: $0) == nil }) else { return }
        var focus: [URL: TimeInterval] = [:]
        if let (url, time) = playheadRecording { focus[url] = time }
        eyes.request(urls, focus: focus)
    }

    /// The playhead stopped: the analysis moves there when that stretch isn't ready.
    func refocusEyeContact() {
        guard eyeContactIsOn, let eyes, let (url, time) = playheadRecording else { return }
        eyes.refocus(url, at: time)
    }

    /// More of the analysis is ready: the preview (and a cover taken from a frame) is drawn again.
    func eyeContactAnalysisDidChange() {
        guard source == .ready, eyeContactIsOn else { return }
        player.redraw()
        if edit.cover?.source.frame != nil { drawCover() }
    }

    /// The recording the playhead shows and its moment there.
    private var playheadRecording: (URL, TimeInterval)? {
        let timeline = edit.timeline
        guard !timeline.segments.isEmpty else { return nil }
        let time = player.currentTime
        let segment = timeline.segments[timeline.segmentIndex(atEdited: time)]
        let url = segment.sourceID.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
        return (url, timeline.sourceTime(forEdited: time))
    }

    // MARK: - What it says

    var eyeContactState: EyeContactState {
        guard eyeContactIsOn else { return .off }
        if eyes?.engineWorks == false { return .unavailable }
        let urls = playedRecordingURLs
        let statuses = urls.compactMap { eyes?.status(of: $0) }
        if statuses.contains(.failed) { return .failed }
        if let behind = statuses.filter({ !$0.isReady }).min(by: { $0.progress < $1.progress }) {
            if case .paused(let reason, let done) = behind { return .paused(reason, done) }
            let readyHere = playheadRecording.map { url, time in
                EyeContactAnalysisStore.load(forRecording: url)?.covers(EyeContactAnalysisService.focusSpan(at: time)) ?? false
            } ?? false
            return .preparing(behind.progress, readyHere: readyHere)
        }
        // Everything asked for is ready (or nothing was asked yet): the share of the frames the edit plays that are corrected.
        var corrected = 0.0, analyzed = 0
        var holds: [EyeContactHold: Int] = [:]
        for clip in [nil] + edit.playedSources.map(\.id) as [UUID?] {
            let spans = edit.timeline.segments.filter { $0.sourceID == clip }.map(\.span)
            guard !spans.isEmpty else { continue }
            let url = clip.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
            guard let plan = EyeContactAnalysisStore.plan(forRecording: url),
                  EyeContactAnalysisStore.load(forRecording: url)?.isComplete == true else { return .preparing(0, readyHere: false) }
            let summary = plan.summary(in: spans)
            corrected += summary.corrected * Double(summary.analyzed)
            analyzed += summary.analyzed
            if let hold = summary.mainHold { holds[hold, default: 0] += summary.analyzed }
        }
        guard analyzed > 0, corrected > 0 else { return .nothingToCorrect(holds.max { $0.value < $1.value }?.key) }
        return .ready(corrected / Double(analyzed))
    }

    /// What the ✦ Smart tile says; nil while Eye Contact is off.
    var smartEyeContactStatus: String? {
        eyeContactState.tileStatus
    }
}
