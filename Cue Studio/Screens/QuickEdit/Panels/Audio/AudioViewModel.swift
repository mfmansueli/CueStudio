//
//  AudioViewModel.swift
//  Cue Studio
//

import Foundation

/// The sound (`EditorPart`): Studio Voice and its comparison with the original, music and sound effects with their beats,
/// voice-overs recorded over the edit with the script shown while they record, and a clip's sound pulled out to a track of its
/// own. What it keeps is its panels' state and the microphone; the sound itself is in the edit, and every change is an undo
/// step through the session.
///
/// Each part of the work is in its own extension (`+Voice`, `+Music`, `+Beats`, `+VoiceOver`, `+NarrationScript`,
/// `+ExtractAudio`).
@MainActor
@Observable
final class AudioViewModel: EditorPart {
    /// The music clip the next sound file replaces ("Replace"); nil adds a new clip.
    var musicReplacementID: UUID?
    var isImportingMusic = false
    /// "Compare with original": the preview plays the take's untreated sound at `originalVolume`, as loud as the treated one.
    var comparesOriginal = false
    var originalVolume: Double?
    /// The treatment being compared; changing it ends the comparison.
    @ObservationIgnored var comparedProcessing: VoiceProcessing?
    /// Edited seconds where the voice-over being recorded started.
    var recordingStart: TimeInterval?
    /// Voice-over's "Show script": the take's script over the preview while a narration records, remembered for every take
    /// (`+NarrationScript`).
    var showsNarrationScript: Bool {
        didSet { editorPreferences.showsNarrationScript = showsNarrationScript }
    }
    /// How far that script has been read, at a steady pace from the start of the recording.
    var narrationPace: NarrationScriptPace
    /// The beats found in the music files, by file (`+Beats`); bumped `beatsFound` when one comes in.
    @ObservationIgnored var beatCache: [String: BeatTracker.Result] = [:]
    @ObservationIgnored var findingBeats: Set<String> = []
    var beatsFound = 0
    /// Beats › Cut on: every beat, every second or every fourth.
    var beatCutEvery = 2
    /// Opens Cue's page in the Settings app (a toast's "Settings" when the microphone is off for Cue); tests count it.
    @ObservationIgnored var opensSettings: @MainActor () -> Void = { AppSettingsLink.open() }

    let session: EditorSession
    let editing: TakeEditing
    /// Copies a sound file picked in Files into the edit's media.
    let importer: EditMediaImporting
    let recorder: VoiceOverRecording
    /// Quick edit's own switches, kept between edits.
    let editorPreferences: EditorPreferencesStoring
    /// How the creator's teleprompter draws a script (font, colour, spacing, speed): the script shown while a narration records
    /// is drawn the same way.
    let prompterLook: PrompterSettings
    /// Hears a sound effect before it's added.
    let soundPreviews: SoundEffectPreviewing

    init(
        session: EditorSession, editing: TakeEditing, importer: EditMediaImporting, recorder: VoiceOverRecording,
        editorPreferences: EditorPreferencesStoring, prompterLook: PrompterSettings, soundPreviews: SoundEffectPreviewing
    ) {
        self.session = session
        self.editing = editing
        self.importer = importer
        self.recorder = recorder
        self.editorPreferences = editorPreferences
        self.prompterLook = prompterLook
        self.soundPreviews = soundPreviews
        showsNarrationScript = editorPreferences.showsNarrationScript
        narrationPace = NarrationScriptPace(speed: editorPreferences.narrationScriptSpeed ?? prompterLook.speed)
        recorder.stoppedByItself = { [weak self] reason in self?.voiceOverStoppedByItself(reason) }
    }

    /// The edit changed: a new treatment isn't what was being compared.
    func editChanged() {
        if comparesOriginal, edit.voiceProcessing != comparedProcessing { endComparison() }
    }

    /// The panel `previous` was left: leaving Studio Voice ends its comparison.
    func panelChanged(from previous: EditorPanel?) {
        if previous == .voice { endComparison() }
    }

    /// The sheet changed: "Replace" asks for the file only for the sheet it opened.
    func sheetChanged(to sheet: EditorSheet?) {
        if sheet != .music { musicReplacementID = nil }
    }

    /// A narration being recorded stops and is kept (leaving a panel, the editor or the app).
    func stopRecordingIfNeeded() {
        if recorder.isRecording { stopVoiceOver() }
    }
}
