//
//  FilterFanMenu.swift
//  Cue Studio
//

import SwiftUI

/// The one action a chip of a `FilterFan` may hold (Delete folder on a folder's chip): in its context menu and among VoiceOver's actions.
struct FilterFanMenu {
    var title: LocalizedStringKey
    var systemImage: String
    var identifier: String
    var action: () -> Void
}
