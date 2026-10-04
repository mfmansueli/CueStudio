//
//  SettingsSheet.swift
//  Cue Studio
//

import Foundation

/// The Settings pages that open as sheets over Settings (v29 · L14, fewer levels): Recording, Remote and Language & Region.
/// Prompter, Personalize and Acknowledgements stay pushed. Kept in `PresentationService`, so a sheet survives the app
/// rebuilding itself when the interface language changes.
enum SettingsSheet: String, Identifiable, Hashable {
    case recording, remote, languageRegion

    var id: String { rawValue }
}
