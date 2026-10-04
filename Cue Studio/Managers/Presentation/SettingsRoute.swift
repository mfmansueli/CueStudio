//
//  SettingsRoute.swift
//  Cue Studio
//

import Foundation

/// The pages Settings pushes (Prompter, Personalize, Acknowledgements); Recording, Remote and Language & Region are sheets
/// (`SettingsSheet`). Technical destinations keep their Settings context when the app language rebuilds the UI.
enum SettingsRoute: Hashable {
    case personalize
    case prompter
    case acknowledgements
}
