//
//  ProfileRoute.swift
//  Cue Studio
//

import Foundation

/// A screen pushed on the Profile stack. Kept in `PresentationService`, so switching the app's
/// language (which rebuilds the interface) comes back to the same screen.
enum ProfileRoute: Hashable {
    case languageAndRegion
    case appLanguage
    case voiceFollowingLanguage
    case scriptLanguage
}
