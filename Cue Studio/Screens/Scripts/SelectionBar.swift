//
//  SelectionBar.swift
//  Cue Studio
//

import SwiftUI

/// Replaces the tab bar while selecting: scripts on Scripts (with the Logbook's ideas shown there), ideas in the Logbook. Folders and
/// Duplicate are for scripts: they are left out where there are none to pick (`onMove` nil), and off while only ideas are picked
/// (`canMove`).
struct SelectionBar: View {
    let count: Int
    /// What it says while nothing is picked.
    var prompt = String(localized: "Select scripts")
    var folders: [String] = []
    var canMove = true
    var onMove: ((String?) -> Void)?
    var onNewFolder: () -> Void = {}
    var onDuplicate: () -> Void = {}
    let onDelete: () -> Void
    var deleteIdentifier = "scripts.deleteSelectionButton"

    var body: some View {
        HStack {
            Text(count == 0 ? prompt : String(localized: "\(count) selected"))
                .font(.subheadline.weight(.semibold))
                .padding(.leading, 22)
            Spacer()
            HStack(spacing: 6) {
                if let onMove {
                    Group {
                        Menu {
                            ForEach(folders, id: \.self) { folder in
                                Button(folder) { onMove(folder) }
                            }
                            Button("Remove from folder", systemImage: "folder.badge.minus") { onMove(nil) }
                            Divider()
                            Button("New folder…", systemImage: "folder.badge.plus", action: onNewFolder)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.cueIcon(.overlay, diameter: 48))
                        .accessibilityLabel(Text("Move to folder"))
                        Button(action: onDuplicate) {
                            Image(systemName: "plus.square.on.square")
                        }
                        .buttonStyle(.cueIcon(.overlay, diameter: 48))
                        .accessibilityLabel(Text("Duplicate"))
                    }
                    .disabled(!canMove)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(Palette.dangerText)
                }
                .buttonStyle(.cueIcon(.overlay, diameter: 48))
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier(deleteIdentifier)
            }
            .disabled(count == 0)
            .padding(.trailing, 8)
        }
        .frame(height: 64)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

#if DEBUG
#Preview {
    SelectionBar(count: 2, folders: ["Brand deals"], onMove: { _ in }, onDelete: {})
        .background(Palette.bg)
}
#endif
