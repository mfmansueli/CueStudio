//
//  SettingsRoute.swift
//  Cue Studio
//

import Foundation

/// Recording, Prompter and Remote are the three pages under "Your setup". Technical destinations
/// keep their Settings context when the app language rebuilds the UI.
enum SettingsRoute: Hashable {
    case languageRegion
    case recording
    case prompter
    case remote
    case acknowledgements
}
