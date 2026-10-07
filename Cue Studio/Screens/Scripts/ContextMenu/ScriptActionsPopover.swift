//
//  ScriptActionsPopover.swift
//  Cue Studio
//

import SwiftUI

/// "More" on a script's swipe: every action on it, in a popover on the row laid out as a menu (iOS can't open a row's own menu from a
/// button): what to do with it, then where it lives and how it's written, then Delete. The folder and the language open the system's
/// submenus in place; an action that opens something else (record, a page, the share sheet, a new folder's name) goes through `perform`,
/// which closes the popover first and runs it once it's gone.
struct ScriptActionsPopover: View {
    let script: Script
    let folders: [String]
    let actions: ScriptActions
    let onShare: () -> Void
    /// Closes the popover, then runs the action.
    let perform: (@escaping () -> Void) -> Void

    var body: some View {
        VStack(spacing: 0) {
            row("Record", systemImage: "video") { actions.record(script) }
            separator
            row("Studio mode", systemImage: "text.alignleft") { actions.studio(script) }
            separator
            row("Edit", systemImage: "pencil") { actions.edit(script) }
            groupGap
            row("Duplicate", systemImage: "plus.square.on.square") { actions.duplicate(script) }
            separator
            folderMenu
            separator
            languageMenu
            separator
            row("Share", systemImage: "square.and.arrow.up") { onShare() }
            groupGap
            row("Delete", systemImage: "trash", role: .destructive) { actions.delete(script) }
        }
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scriptActions.menu")
    }

    // MARK: - Rows

    /// A menu row: the name at the start, the symbol at the end, as the system's menus have them.
    private func rowLabel(_ title: LocalizedStringKey, systemImage: String, role: ButtonRole? = nil) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            Image(systemName: systemImage).frame(width: 22)
        }
        .font(.body)
        .foregroundStyle(role == .destructive ? Palette.dangerText : Palette.ink)
        .padding(.horizontal, 16)
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role) { perform(action) } label: {
            rowLabel(title, systemImage: systemImage, role: role)
        }
        .buttonStyle(.plain)
    }

    private var separator: some View {
        Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16)
    }

    /// The wider break between groups, as in the system's menus.
    private var groupGap: some View {
        Rectangle().fill(Palette.separator).frame(height: 6).opacity(0.6)
    }

    private var folderMenu: some View {
        Menu {
            ForEach(folders, id: \.self) { folder in
                Button {
                    perform { actions.move(script, folder) }
                } label: {
                    if script.folder == folder { Label(folder, systemImage: "checkmark") } else { Text(folder) }
                }
            }
            if script.folder != nil {
                Button("Remove from folder", systemImage: "folder.badge.minus") { perform { actions.move(script, nil) } }
            }
            Divider()
            Button("New folder…", systemImage: "folder.badge.plus") { perform { actions.moveToNewFolder(script) } }
        } label: {
            rowLabel("Move to folder", systemImage: "folder")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    /// The language the script is written in, changed in place (Auto-detect or one of Cue's), with the current one checked.
    private var languageMenu: some View {
        Menu {
            Picker(selection: Binding(get: { script.language }, set: { language in perform { actions.setLanguage(script, language) } })) {
                Text("Auto-detect").tag(CueLanguage?.none)
                ForEach(CueLanguage.allCases) { language in
                    Text(verbatim: language.nativeName).tag(Optional(language))
                }
            } label: {
                Text("Script Language")
            }
            .pickerStyle(.inline)
        } label: {
            rowLabel("Script Language", systemImage: "character.bubble")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
