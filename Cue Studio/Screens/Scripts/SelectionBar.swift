//
//  SelectionBar.swift
//  Cue Studio
//

import SwiftUI

/// Replaces the tab bar while selecting scripts.
struct SelectionBar: View {
    let count: Int
    let folders: [String]
    let onMove: (String?) -> Void
    let onNewFolder: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(count == 0 ? String(localized: "Select scripts") : String(localized: "\(count) selected"))
                .font(.subheadline.weight(.semibold))
                .padding(.leading, 22)
            Spacer()
            HStack(spacing: 6) {
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
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(Palette.danger)
                }
                .buttonStyle(.cueIcon(.overlay, diameter: 48))
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier("scripts.deleteSelectionButton")
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
    SelectionBar(count: 2, folders: ["Brand deals"], onMove: { _ in }, onNewFolder: {}, onDuplicate: {}, onDelete: {})
        .background(Palette.bg)
}
#endif
