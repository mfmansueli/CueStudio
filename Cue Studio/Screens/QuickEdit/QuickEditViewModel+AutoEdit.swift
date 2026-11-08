//
//  QuickEditViewModel+AutoEdit.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Auto edit (E5, plan §14 and E4 decision A): a first pass that puts together steps that already work on their own, from its
/// own button on the main bar (it touches captions and zoom too, so not Clean up's, which is the speech's Quick pass):
/// - **Clean up speech:** what Clean up is clear about, the last try of each line said more than once kept (`+QuickPass`);
/// - **Captions:** from the voice, only when there are none (the creator's lines are never replaced);
/// - **Zoom on key lines:** off unless picked, a phrase zoom on lines with a clear number, value or name (`AutoEditZoomPicker`).
/// Nothing else: no music, effects, styles or other cuts. Listening comes first and changes nothing; everything it applies is one
/// undo step (`EditDocument.beginChange`), and Cancel while it runs leaves the edit as it was. After, the sheet shows what each
/// step did, Before | After on the preview, and Turn off for each step, which takes back only that step's changes
/// (`AutoEditRecord`, kept with the edit: reopening Auto edit shows them again).
extension QuickEditViewModel {
    /// Opens Auto edit: the last run's results when one is still on, else the steps to pick.
    func openAutoEdit() {
        guard isReady else { return }
        player.pause()
        panel = nil
        if let record = edit.autoEdit, AutoEditStep.allCases.contains(where: record.isOn) {
            autoEdit = AutoEditSession(steps: [], phase: .done)
        } else {
            var steps: Set<AutoEditStep> = [.speech]
            if edit.captions.isEmpty { steps.insert(.captions) }
            autoEdit = AutoEditSession(steps: steps)
        }
        sheet = .autoEdit
    }

    /// Whether the captions step can run: only on a video without captions.
    var autoEditCanMakeCaptions: Bool { edit.captions.isEmpty }

    /// Whether the zoom step has lines to read: captions there or made by the run.
    func autoEditCanZoom(_ session: AutoEditSession) -> Bool {
        !edit.captions.isEmpty || session.isOn(.captions)
    }

    /// Runs the picked steps.
    func runAutoEdit() {
        guard let session = autoEdit, session.phase == .choosing, !session.steps.isEmpty, isReady else { return }
        session.task = Task { [weak self] in await self?.performAutoEdit(session) }
    }

    /// Cancel while it runs: listening stops and nothing stays changed.
    func cancelAutoEdit() {
        guard let session = autoEdit, session.isWorking else { return }
        session.task?.cancel()
        captions.cancelCaptions()
        document.cancelChanges()
        session.phase = .choosing
    }

    /// The sheet closed: back to After when it showed Before.
    func closeAutoEdit() {
        if let session = autoEdit {
            if session.isWorking { cancelAutoEdit() }
            if session.showsBefore { showAutoEditBefore(false) }
        }
        autoEdit = nil
        if sheet == .autoEdit { sheet = nil }
    }

    /// Before | After: the edit as it was before the run, or with it; only while the run is still the last change.
    func showAutoEditBefore(_ before: Bool) {
        guard let session = autoEdit, session.phase == .done, before != session.showsBefore, canCompareAutoEdit else { return }
        session.beforeRecord = before ? edit.autoEdit : nil
        if before { session.beforeLines = edit.captions.count }
        if before { document.undo() } else { document.redo() }
        session.showsBefore = before
        player.seek(to: 0)
    }

    /// Before | After works while nothing was changed after the run.
    var canCompareAutoEdit: Bool {
        guard let session = autoEdit, let steps = session.stepsAfterRun else { return false }
        let past = document.history.past.count
        return session.showsBefore ? past == steps - 1 && document.canRedo : past == steps
    }

    /// What a step did, for the results ("7 cuts · −6.1s"), or why it did nothing.
    /// The record the results show: the edit's, or the run's while Before shows the edit without it.
    var autoEditShownRecord: AutoEditRecord? {
        autoEdit?.showsBefore == true ? autoEdit?.beforeRecord : edit.autoEdit
    }

    func autoEditResult(_ step: AutoEditStep) -> String {
        guard let record = autoEditShownRecord else { return String(localized: "Didn't run") }
        if record.offSteps.contains(step) { return String(localized: "Turned off") }
        if step == .captions, !record.madeCaptions, !record.ranSteps.contains(.captions), !edit.captions.isEmpty {
            return String(localized: "Your captions stay")
        }
        guard record.ranSteps.contains(step) else { return String(localized: "Didn't run") }
        switch step {
        case .speech:
            guard !record.removedSuggestions.isEmpty else { return String(localized: "Nothing clear to take out") }
            let seconds = DurationText.tenths(record.removedSeconds)
            return String(localized: "\(record.removedSuggestions.count) cuts · −\(seconds)", comment: "Auto edit: pauses, ums and tries taken out, and the time saved")
        case .captions:
            let lines = autoEdit?.showsBefore == true ? autoEdit?.beforeLines ?? 0 : edit.captions.count
            return String(localized: "\(lines) lines to check")
        case .zoom:
            return record.zoomIDs.isEmpty
                ? String(localized: "No line with a clear number or name")
                : String(localized: "Zoom on \(record.zoomIDs.count) lines")
        }
    }

    /// Turns one step of the last run off, alone, as one undo step: the speech's cuts come back, its captions hide (the lines
    /// stay, Captions shows them again), its zooms go (the creator's stay).
    func turnOffAutoEditStep(_ step: AutoEditStep) {
        guard isReady, var record = edit.autoEdit, record.isOn(step) else { return }
        if autoEdit?.showsBefore == true { showAutoEditBefore(false) }
        document.beginChange(by: .gesture)
        switch step {
        case .speech:
            clips.putBackAll(Set(record.removedSuggestions))
        case .captions:
            changeEdit { $0.showsCaptions = false }
        case .zoom:
            let ids = Set(record.zoomIDs)
            changeEdit { $0.phraseZooms.removeAll { ids.contains($0.id) } }
        }
        record.offSteps.insert(step)
        changeEdit { $0.autoEdit = record }
        document.endChange(by: .gesture)
        Haptics.selection()
        toast.show(String(localized: "\(step.title) turned off"), action: undoAction)
    }

    /// Starts picking steps again from the results.
    func autoEditAgain() {
        guard let session = autoEdit else { return }
        var steps: Set<AutoEditStep> = [.speech]
        if edit.captions.isEmpty { steps.insert(.captions) }
        session.steps = steps
        session.showsBefore = false
        session.stepsAfterRun = nil
        session.phase = .choosing
    }

    // MARK: - Private

    private func performAutoEdit(_ session: AutoEditSession) async {
        session.phase = .working(.listening)
        if session.isOn(.speech) { await clips.analyzeIfNeeded() }
        guard !Task.isCancelled, autoEdit === session else { return }
        document.beginChange(by: .gesture)
        var record = AutoEditRecord()
        if session.isOn(.captions), edit.captions.isEmpty {
            session.phase = .working(.captions)
            captions.makeCaptions()
            while captions.captionState.isWorking {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
            }
            record.madeCaptions = !edit.captions.isEmpty
            if record.madeCaptions { record.ranSteps.insert(.captions) }
        }
        guard !Task.isCancelled, autoEdit === session else { return }
        session.phase = .working(.applying)
        if session.isOn(.speech), clips.analysis == .done {
            record.ranSteps.insert(.speech)
            clips.keepLastTries()
            let saving = clips.cleanUpSaving
            if let removed = clips.removeMarkedCleanUp() {
                record.removedSuggestions = removed.map(\.id)
                record.removedSeconds = saving
            }
        }
        if session.isOn(.zoom), !edit.captions.isEmpty {
            record.ranSteps.insert(.zoom)
            let language = edit.captionLanguage.map { NLLanguage(rawValue: $0.languageCode) }
            let playing = captions.captionLinesInPlayOrder.filter { captions.editedSpan(ofCaption: $0.id) != nil }
            let zooms = AutoEditZoomPicker.zooms(for: playing, existing: edit.phraseZooms, strength: session.zoomStrength, language: language)
            if !zooms.isEmpty {
                changeEdit { $0.phraseZooms = ($0.phraseZooms + zooms).sorted { $0.span.start < $1.span.start } }
                record.zoomIDs = zooms.map(\.id)
            }
        }
        changeEdit { $0.autoEdit = record }
        document.endChange(by: .gesture)
        session.stepsAfterRun = document.history.past.count
        session.phase = .done
        clips.cleanUpMarks = [:]
        player.seek(to: 0)
        Haptics.success()
    }
}
