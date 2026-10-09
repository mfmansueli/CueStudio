//
//  SettingsRoute.swift
//  Cue Studio
//

import Foundation

/// The pages Settings pushes, every one of them (v30): the root's pages, and the pages under them (Microphone, Font, Social
/// safe zone, App icon, Permissions). Kept in `PresentationService`, so the creator stays where they were when the app
/// rebuilds itself after a language change.
enum SettingsRoute: Hashable {
    case recording, microphone
    case prompter, font, safeZone
    case remote
    case myCueVoice
    case personalize, appIcon
    case languageRegion
    case notifications
    case privacy, permissions
    case acknowledgements
}
