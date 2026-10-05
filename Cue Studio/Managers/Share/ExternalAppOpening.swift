//
//  ExternalAppOpening.swift
//  Cue Studio
//

import Foundation

/// Opens other apps. Swappable so tests never leave Cue. There is no "is it installed?" question: iOS 27 deprecates
/// `canOpenURL` ("prefer attempting to open URLs and handling any failures"), so a destination is tried and `false` means
/// the app isn't there (or wouldn't open).
protocol ExternalAppOpening: AnyObject {
    /// Opens the platform's app, only that: it says nothing about any video. False when it can't be opened.
    func open(_ destination: ShareDestination) async -> Bool
    /// Opens a URL; false when nothing handled it.
    func open(_ url: URL) async -> Bool
}
