//
//  ExternalAppOpening.swift
//  Cue Studio
//

import Foundation

/// Opens a platform's app. Swappable so tests never leave Cue.
protocol ExternalAppOpening: AnyObject {
    /// False when the app isn't installed (or can't be opened).
    func open(_ destination: ShareDestination) async -> Bool
}
