//
//  SettingsRoute.swift
//  Cue Studio
//

import Foundation

/// Technical destinations keep their Settings context when the app language rebuilds the UI.
enum SettingsRoute: Hashable {
    case languageRegion
    case creatorSetup
    case acknowledgements
}
