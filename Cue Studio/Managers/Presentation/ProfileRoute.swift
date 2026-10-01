//
//  ProfileRoute.swift
//  Cue Studio
//

import Foundation

/// Screens pushed on the Profile tab that must survive the interface being rebuilt (a new app
/// language rebuilds every screen; the path brings the creator back to where they were).
enum ProfileRoute: Hashable {
    /// Profile › Settings › Language & Region.
    case languageRegion
    /// Profile › Settings › Acknowledgements (the fonts' licenses).
    case acknowledgements
}
