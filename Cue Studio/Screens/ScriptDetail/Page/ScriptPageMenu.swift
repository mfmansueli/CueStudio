//
//  ScriptPageMenu.swift
//  Cue Studio
//

import SwiftUI

/// The ••• of the script page: ✦ Improve with Cue, Versions & options (the full editor), Script
/// details and Studio mode, then what every script menu has.
struct ScriptPageMenu: View {
    let script: Script
    let folders: [String]
    let actions: ScriptActions
    let onImprove: () -> Void
    let onVersions: () -> Void
    let onDetails: () -> Void

    var body: some View {
        Button(action: onImprove) { Label("Improve with Cue", systemImage: "sparkles") }
        Button(action: onVersions) { Label("Versions & options", systemImage: "square.stack") }
        Button(action: onDetails) { Label("Script details", systemImage: "info.circle") }
        Button { actions.studio(script) } label: { Label("Studio mode", systemImage: "text.alignleft") }
        Divider()
        ScriptActionsMenu(script: script, folders: folders, actions: actions, showsOpeningActions: false)
    }
}
