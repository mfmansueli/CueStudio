//
//  IntentRoute.swift
//  Cue Studio
//

import Foundation

/// Where a Siri or Shortcuts action asked the app to go.
enum IntentRoute: Hashable {
    /// Open the camera with this script.
    case record(UUID)
    /// Open "New script".
    case newScript
}
