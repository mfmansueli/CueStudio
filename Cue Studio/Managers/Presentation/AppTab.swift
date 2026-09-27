//
//  AppTab.swift
//  Cue Studio
//

import Foundation

enum AppTab: Hashable {
    case scripts, takes, profile
    /// Not a real destination: selecting it opens "Start recording".
    case record
}
