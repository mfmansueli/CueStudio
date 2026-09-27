//
//  ScriptActionsMenu.swift
//  Cue Studio
//

import SwiftUI

/// Menu items for a script. Use inside `.contextMenu` or `Menu`.
struct ScriptActionsMenu: View {
    let script: Script
    let folders: [String]
    let actions: ScriptActions

    var body: some View {
        Button("Record", systemImage: "video") { actions.record(script) }
        Button("Studio mode", systemImage: "text.alignleft") { actions.studio(script) }
        Button("Edit", systemImage: "pencil") { actions.edit(script) }
        Divider()
        Button("Duplicate", systemImage: "plus.square.on.square") { actions.duplicate(script) }
        Menu("Move to folder", systemImage: "folder") {
            ForEach(folders, id: \.self) { folder in
                Button {
                    actions.move(script, folder)
                } label: {
                    if script.folder == folder {
                        Label(folder, systemImage: "checkmark")
                    } else {
                        Text(folder)
                    }
                }
            }
            if script.folder != nil {
                Button("Remove from folder", systemImage: "folder.badge.minus") { actions.move(script, nil) }
            }
            Divider()
            Button("New folder…", systemImage: "folder.badge.plus") { actions.moveToNewFolder(script) }
        }
        ShareLink(item: "\(script.displayTitle)\n\n\(script.text)", subject: Text(script.displayTitle)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(script) }
    }
}
