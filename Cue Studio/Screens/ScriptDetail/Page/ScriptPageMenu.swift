//
//  ScriptPageMenu.swift
//  Cue Studio
//

import SwiftUI

/// The ••• of the script page: ✦ Improve with Cue (with Apple Intelligence), Script details, Studio mode and Remind me…, then what
/// every script menu has.
struct ScriptPageMenu: View {
    let script: Script
    let folders: [String]
    let actions: ScriptActions
    /// Apple Intelligence can write: without it there is no Improve.
    var hasAI = true
    let onImprove: () -> Void
    let onDetails: () -> Void
    /// "Remind me…": a reminder to come back to this script.
    let onRemind: () -> Void

    @Environment(TopicTaggingService.self) private var tagging
    @Environment(ScriptLibraryService.self) private var library

    var body: some View {
        if hasAI { Button(action: onImprove) { Label("Improve with Cue", systemImage: "sparkles") } }
        Button(action: onDetails) { Label("Script details", systemImage: "info.circle") }
        Button { actions.studio(script) } label: { Label("Studio mode", systemImage: "text.alignleft") }
        Button(action: onRemind) { Label("Remind me…", systemImage: "bell") }
            .accessibilityIdentifier("page.remindMe")
        if !tagging.topics.isEmpty {
            // Cue picked it on this iPhone; the creator has the last word.
            Menu {
                ForEach(tagging.topics) { topic in
                    Button {
                        library.setTopic(topic.id, of: script.id)
                    } label: {
                        if script.topic == topic.id { Label(topic.label, systemImage: "checkmark") } else { Text(topic.label) }
                    }
                }
                Button("No topic") { library.setTopic("", of: script.id) }
            } label: { Label("Topic", systemImage: "circle.hexagongrid") }
            .accessibilityIdentifier("page.topicMenu")
        }
        Divider()
        ScriptActionsMenu(script: script, folders: folders, actions: actions, showsOpeningActions: false)
    }
}
