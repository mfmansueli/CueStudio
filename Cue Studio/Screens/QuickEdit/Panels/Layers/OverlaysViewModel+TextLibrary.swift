//
//  OverlaysViewModel+TextLibrary.swift
//  Cue Studio
//

import Foundation

/// The creator's saved text looks (`StyleLibrary` of `TextLook`), managed like their caption and cover styles: saved with a
/// name from Text style › Styles, renamed, updated with the picked text's look, duplicated, favored, picked as the one new
/// texts start in (on a video with no style of its own yet) and deleted with Undo. A text keeps its own look: none of this
/// changes a text already made.
extension OverlaysViewModel {
    var suggestedTextStyleName: String { textStyles.nextName() }

    /// Keeps the picked text's look as a style named `name`.
    func saveTextStyle(named name: String) {
        guard let id = styledTextID, let text = edit.texts.first(where: { $0.id == id }) else { return }
        let style = textStyles.add(TextLook(of: text), named: name)
        writeTextStyles()
        toast.show(String(localized: "Saved as \(style.name)"))
    }

    func renameTextStyle(_ id: UUID, to name: String) {
        textStyles.rename(id, to: name)
        writeTextStyles()
    }

    /// The saved style takes the picked text's look; texts already made keep theirs.
    func updateTextStyle(_ id: UUID) {
        guard let picked = styledTextID, let text = edit.texts.first(where: { $0.id == picked }), let style = textStyles.style(id) else { return }
        textStyles.update(id, with: TextLook(of: text))
        writeTextStyles()
        toast.show(String(localized: "\(style.name) updated · Videos already made keep theirs"))
    }

    /// A copy of a saved style, or one of Cue's presets saved as the creator's own.
    func duplicateTextStyle(_ key: StyleKey, name: String) {
        switch key {
        case .saved(let id):
            guard let copy = textStyles.duplicate(id) else { return }
            writeTextStyles()
            toast.show(String(localized: "Saved as \(copy.name)"))
        case .builtIn(let raw):
            guard let preset = TypePreset(rawValue: raw) else { return }
            let style = textStyles.add(preset.look(for: .title), named: name)
            writeTextStyles()
            toast.show(String(localized: "Saved as \(style.name)"))
        }
    }

    func toggleFavoriteTextStyle(_ key: StyleKey) {
        textStyles.toggleFavorite(key)
        writeTextStyles()
    }

    /// New texts start in `key` on videos with no style of their own; picked again, Cue's own start.
    func toggleDefaultTextStyle(_ key: StyleKey, name: String) {
        let isDefault = textStyles.isDefault(key)
        textStyles.setDefault(isDefault ? nil : key)
        writeTextStyles()
        toast.show(isDefault ? String(localized: "New texts start in Cue's style") : String(localized: "New texts start in \(name)"))
    }

    /// Deletes a saved style; the toast's Undo puts it back. Texts that wear it keep their look.
    func deleteTextStyle(_ id: UUID) {
        guard let removal = textStyles.remove(id) else { return }
        writeTextStyles()
        toast.show(
            String(localized: "\(removal.style.name) deleted"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in
                self?.textStyles.restore(removal)
                self?.writeTextStyles()
            }
        )
    }

    func writeTextStyles() {
        styles.textStyles = textStyles
    }

    /// The look a new text starts in on a video with no style of its own: the default style, if the creator picked one.
    var defaultTextStart: (look: TextLook, preset: TypePreset?)? {
        guard edit.textLook == nil, edit.creatorStyle == nil, let start = textStyles.defaultStyle else { return nil }
        switch start {
        case .saved(let id): return textStyles.style(id).map { ($0.look, nil) }
        case .builtIn(let raw): return TypePreset(rawValue: raw).map { ($0.look(for: .title), $0) }
        }
    }
}
