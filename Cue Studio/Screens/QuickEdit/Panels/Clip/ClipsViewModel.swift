//
//  ClipsViewModel.swift
//  Cue Studio
//

import Foundation

/// The video track (`EditorPart`): its clips cut, split, copied and deleted, sped up or along a curve, zoomed and turned down,
/// joined by transitions, reordered and added from other takes and videos (a montage), reversed and replaced; and what takes
/// time out of it: Pauses with Clean Up's suggestions, and Edit by text. What it keeps is its panels' state; the cuts are in
/// the edit, and every change is an undo step through the session. The timeline that draws every part's tracks, and its
/// gestures, are the editor's (`QuickEditViewModel+Timeline`, `+Layers`).
///
/// Each part of the work is in its own extension (`+Cutting`, `+Settings`, `+SpeedCurve`, `+Transitions`, `+Montage`,
/// `+Reverse`, `+ReplaceClip`, `+Pauses`, `+CleanUp`, `+TranscriptEdit`).
@MainActor
@Observable
final class ClipsViewModel: EditorPart {
    /// Clean Up listening to the take.
    enum Analysis: Equatable {
        case idle, running, done, failed
    }

    /// How long before a cut the playhead waits after a transition is picked, so Play shows it.
    static let transitionLeadIn: TimeInterval = 1

    /// Clean Up listening to the take (`+CleanUp`).
    var analysis: Analysis = .idle
    /// Pauses, filler words and retakes marked differently from their default while Pauses is open (by default pauses and
    /// sure words are marked to go).
    var cleanUpMarks: [UUID: Bool] = [:]
    /// The pause or word being listened to in Pauses.
    var listeningID: UUID?
    /// Edit by text: the picked words (indices in `transcriptWords`).
    var transcriptSelection: ClosedRange<Int>?
    /// Speed shows its Curve tab (`+SpeedCurve`).
    var showsSpeedCurves = false
    /// A point of the speed curve is being dragged (`+SpeedCurve`).
    @ObservationIgnored var shapesCurve = false
    /// A clip's handle is held on the timeline (the editor says so): curved clips' sound steps meanwhile, like a curve's point.
    @ObservationIgnored var holdsClipHandle = false

    let session: EditorSession
    let editing: TakeEditing
    /// The library of takes: a montage adds others from it, with their scripts.
    let takes: TakeLibraryService
    let library: ScriptLibraryService
    /// What a script is heard in, for Clean Up (`LanguageService.captionRequest(for:)`).
    let speechLanguageFor: (Script?) -> SpeechLanguageRequest

    init(
        session: EditorSession, editing: TakeEditing, takes: TakeLibraryService, library: ScriptLibraryService,
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest
    ) {
        self.session = session
        self.editing = editing
        self.takes = takes
        self.library = library
        speechLanguageFor = speechLanguage
    }

    /// The language the take is heard in, for Clean Up: the script's (never Voice Following's or the interface's).
    var speechLanguage: SpeechLanguageRequest {
        speechLanguageFor(captionScript)
    }

    /// "Pauses longer than": shorter pauses aren't listed and stay as natural ones (kept with the edit).
    var pauseThreshold: TimeInterval {
        get { edit.pauseThreshold }
        set { changeEdit(key: "pauseThreshold") { $0.pauseThreshold = newValue } }
    }

    /// The recording opened: a take whose every recording was listened to already has its suggestions.
    func opened() {
        if edit.cleanUpAnalyzed, edit.recordingsToCleanUp.isEmpty { analysis = .done }
    }

    /// The edit changed (from `previous`): Edit by text picks words by their place in the list, which any change of the cuts
    /// moves (the sheet lets the timeline be used behind it).
    func editChanged(from previous: TakeEdit) {
        if previous.timeline != edit.timeline { transcriptSelection = nil }
    }

    /// The panel changed to `next`: Pauses opens with nothing marked by hand and starts listening (leaving it doesn't stop
    /// that).
    func panelChanged(to next: EditorPanel?) {
        guard next == .pauses else { return }
        cleanUpMarks = [:]
        listenForCleanUp()
    }

    /// "Clip 2 of 3, 4.2 seconds, playhead at 00:07.1": what VoiceOver reads on the timeline.
    var timelineAccessibilityValue: String {
        let timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: player.currentTime)
        let length = DurationText.tenths(timeline.segments[index].duration)
        let playhead = DurationText.editor(player.currentTime)
        var value = String(localized: "Clip \(index + 1) of \(timeline.segments.count), \(length), playhead at \(playhead)")
        if selectedSegmentIndex == index { value += ", " + String(localized: "selected") }
        return value
    }
}
