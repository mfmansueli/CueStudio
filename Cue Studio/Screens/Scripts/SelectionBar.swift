//
//  SelectionBar.swift
//  Cue Studio
//

import SwiftUI

/// Replaces the tab bar while selecting: scripts on Scripts (with the Logbook's ideas shown there), ideas in the Logbook. Folders and
/// Duplicate are for scripts: they are left out where there are none to pick (`onMove` nil), and off while only ideas are picked
/// (`canMove`). Beside Delete, Select all picks everything shown, and once all of it is picked lets it all go (owner, 31/10/2026).
struct SelectionBar: View {
    let count: Int
    /// What it says while nothing is picked.
    var prompt = String(localized: "Select scripts")
    var folders: [String] = []
    var canMove = true
    var onMove: ((String?) -> Void)?
    var onNewFolder: () -> Void = {}
    var onDuplicate: () -> Void = {}
    /// Everything shown is picked: the button lets it all go.
    let allSelected: Bool
    let onSelectAll: () -> Void
    let onDelete: () -> Void
    var deleteIdentifier = "scripts.deleteSelectionButton"
    var selectAllIdentifier = "scripts.selectAllButton"

    var body: some View {
        HStack {
            Text(count == 0 ? prompt : String(localized: "\(count) selected"))
                .cueFont(.subheadline, weight: .semibold)
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
                    .disabled(!canMove || count == 0)
                }
                Button {
                    Haptics.selection()
                    onSelectAll()
                } label: {
                    Image(systemName: allSelected ? "checklist.unchecked" : "checklist.checked")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.cueIcon(.overlay, diameter: 48))
                .accessibilityLabel(allSelected ? Text("Deselect all") : Text("Select all"))
                .accessibilityIdentifier(selectAllIdentifier)
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(Palette.dangerText)
                }
                .buttonStyle(.cueIcon(.overlay, diameter: 48))
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier(deleteIdentifier)
                .disabled(count == 0)
            }
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
    SelectionBar(count: 2, folders: ["Brand deals"], onMove: { _ in }, allSelected: false, onSelectAll: {}, onDelete: {})
        .background(Palette.bg)
}
#endif
