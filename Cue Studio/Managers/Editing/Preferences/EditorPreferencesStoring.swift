//
//  EditorPreferencesStoring.swift
//  Cue Studio
//

import Foundation

/// How the creator left Quick edit's own switches, kept between edits on this device (any take).
@MainActor
protocol EditorPreferencesStoring: AnyObject {
    /// Voice-over's "Show script": the take's script over the preview while a narration records (on until turned off).
    var showsNarrationScript: Bool { get set }
    /// How fast that script scrolls, on `PrompterSettings.speed`'s scale; nil reads at the prompter's speed.
    var narrationScriptSpeed: Double? { get set }
}
