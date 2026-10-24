//
//  AudioViewModel+NarrationScript.swift
//  Cue Studio
//

import Foundation

/// Voice-over's "Show script": while a narration records, the take's script shows over the top of the preview, drawn like the
/// creator's teleprompter, scrolling at a steady pace from the moment the recording starts (a tap holds it and goes on). Before
/// recording it shows the start. Only on screen: nothing of it goes into the video. A take without a script offers nothing.
extension AudioViewModel {
    /// The script the take was recorded with, without its cues; nil for a freestyle take or an empty script.
    var narrationScriptText: String? {
        guard let text = captionScript?.text else { return nil }
        let spoken = CueParser.stripCues(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return spoken.isEmpty ? nil : spoken
    }

    /// Voice-over offers "Show script".
    var offersNarrationScript: Bool { narrationScriptText != nil }

    /// The prompter's look for the narration: its font, colour, spacing and alignment, with the margins of a preview and the
    /// spoken words only (cues aren't read aloud).
    var narrationLook: PrompterSettings {
        var look = prompterLook
        look.margin = 14
        look.showsCues = false
        return look
    }

    /// Which way the script reads: its language's direction, whatever the interface's is.
    var narrationReadsRightToLeft: Bool {
        guard let script = captionScript else { return false }
        return ScriptDirection.isRightToLeft(language: script.language, text: script.text)
    }

    func toggleNarrationScript() {
        showsNarrationScript.toggle()
    }

    /// A tap on the script while recording: holds it, or goes on.
    func toggleNarrationPause(at now: Date = .now) {
        guard recordingStart != nil else { return }
        narrationPace.togglePause(at: now)
        Haptics.selection()
    }

    /// The speed slider under the switch; remembered for the next narration.
    func setNarrationSpeed(_ speed: Double, at now: Date = .now) {
        narrationPace.setSpeed(speed, at: now)
        editorPreferences.narrationScriptSpeed = narrationPace.speed
    }
}
