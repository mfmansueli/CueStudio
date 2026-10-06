//
//  SettingsBindings.swift
//  Cue Studio
//

import SwiftUI

/// What the Prompter and Recording rows read and write: the creator's defaults (Settings), or the settings of the recording
/// in front of them (Aa in the recorder), so one page serves both.
struct SettingsBindings {
    var prompter: Binding<PrompterSettings>
    var camera: Binding<CameraSettings>
    /// The screen the reading line's percent is measured against.
    var screenScale: ReadingLinePercent = .standard
}
