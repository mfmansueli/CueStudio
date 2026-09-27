//
//  QuickEditViewModel.swift
//  Cue Studio
//

import Foundation

/// Quick edit of one take: every change goes into a `TakeEdit` recipe; Done saves it on the take
/// (with the new length) and marks it edited. The recording itself is never changed.
@MainActor
@Observable
final class QuickEditViewModel {
    var tool: QuickEditTool = .trim
    var edit: TakeEdit
    /// Playhead, in seconds of the original recording.
    var playhead: TimeInterval
    /// Start of the section tapped on the trim strip.
    private(set) var selectedSegmentStart: TimeInterval?
    private(set) var isFindingSilences = false
    private(set) var isWritingCaptions = false

    let take: Take
    private let takes: TakeLibraryService
    private let library: ScriptLibraryService
    private let editing: TakeEditing
    private let toast: ToastService

    init(take: Take, takes: TakeLibraryService, library: ScriptLibraryService, editing: TakeEditing, toast: ToastService) {
        self.take = take
        self.takes = takes
        self.library = library
        self.editing = editing
        self.toast = toast
        edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        playhead = (take.edit?.trimStart ?? 0) + (take.edit?.sourceDuration ?? take.duration) * 0.28
    }

    // MARK: - Reading

    var videoURL: URL { takes.videoURL(for: take) }

    /// "1:04 → 0:58"
    var durationChange: String {
        DurationText.clock(edit.sourceDuration) + " → " + DurationText.clock(edit.editedDuration)
    }

    var playheadLabel: String { DurationText.clock(playhead) }

    var canDeleteSelection: Bool { selectedSegmentStart != nil }

    /// "Remove silences · 4" or "Silences removed · −3s".
    var silenceLabel: String {
        if edit.removesSilences {
            let cut = Int(SilenceDetector.totalDuration(of: edit.silences).rounded())
            return String(localized: "Silences removed · −\(cut)s")
        }
        return edit.silences.isEmpty
            ? String(localized: "Remove silences")
            : String(localized: "Remove silences · \(edit.silences.count)")
    }

    // MARK: - Trim

    func movePlayhead(to time: TimeInterval) {
        playhead = min(edit.sourceDuration, max(0, time))
        selectedSegmentStart = edit.segments.first { !$0.isRemoved && $0.span.contains(playhead) }?.span.start
    }

    func setTrimStart(_ time: TimeInterval) {
        edit.setTrim(start: time)
        playhead = edit.trimStart
    }

    func setTrimEnd(_ time: TimeInterval) {
        edit.setTrim(end: time)
        playhead = edit.trimEnd
    }

    func split() {
        if edit.split(at: playhead) {
            selectedSegmentStart = nil
            toast.show(String(localized: "Split at \(DurationText.clock(playhead))"))
        } else {
            toast.show(String(localized: "Move the playhead inside the clip"))
        }
    }

    func deleteSelection() {
        guard let start = selectedSegmentStart else {
            toast.show(String(localized: "Tap a section to select it"))
            return
        }
        if edit.removeSegment(containing: start) {
            selectedSegmentStart = nil
            toast.show(String(localized: "Section deleted"))
        } else {
            toast.show(String(localized: "Keep at least one section"))
        }
    }

    /// Finds the pauses the first time, then turns cutting them on and off.
    func toggleRemoveSilences() async {
        if edit.silences.isEmpty {
            isFindingSilences = true
            defer { isFindingSilences = false }
            guard let silences = try? await editing.silences(inVideoAt: videoURL), !silences.isEmpty else {
                toast.show(String(localized: "No long pauses in this take"))
                return
            }
            edit.silences = silences
        }
        edit.removesSilences.toggle()
    }

    // MARK: - Adjust

    func autoAdjust() {
        edit.exposure = 14
        edit.contrast = 10
        edit.warmth = 8
        toast.show(String(localized: "Auto-enhanced"))
    }

    // MARK: - Crop

    func setAspect(_ aspect: AspectRatio) {
        edit.aspect = aspect
        edit.cropOffset = 0
    }

    func resetCropPosition() {
        edit.cropOffset = 0
    }

    // MARK: - Captions

    /// Captions come from the script (or, freestyle, from what the model hears), timed to the voice.
    func setShowsCaptions(_ shows: Bool) async {
        edit.showsCaptions = shows
        guard shows, edit.captions.isEmpty else { return }
        isWritingCaptions = true
        defer { isWritingCaptions = false }
        let script = library.script(id: take.scriptID)?.text ?? ""
        edit.captions = await editing.captions(forVideoAt: videoURL, script: script, duration: edit.sourceDuration)
        if edit.captions.isEmpty {
            edit.showsCaptions = false
            toast.show(String(localized: "No script to caption this take"))
        }
    }

    func setCaptionStyle(_ style: CaptionStyle) async {
        edit.captionStyle = style
        if !edit.showsCaptions { await setShowsCaptions(true) }
    }

    // MARK: - Done

    func done() {
        takes.applyEdit(edit, to: take.id)
        toast.show(String(localized: "Edits saved to \(take.label)"))
    }
}
