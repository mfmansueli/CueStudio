//
//  LibraryFileSweep.swift
//  Cue Studio
//

import Foundation

/// Gives back the space of what the creator removed, once a launch, after `EditStorageCleaner`: library files and kit logos
/// their list no longer names (a removed asset or kit, past its session's Undo; an import stopped halfway), and the files of a
/// font family the creator removed once nothing names it any more (no video, draft, undo step, saved style or kit). Files
/// changed in the last `settleAge` are left for the next launch, so nothing being written right now is touched.
nonisolated enum LibraryFileSweep {
    static let settleAge: TimeInterval = 10 * 60

    /// The files of `files` (name and last change) that `list` (the folder's JSON, as text) doesn't name and that settled.
    static func strays(files: [String: Date], list: String, launchedAt: Date) -> Set<String> {
        let settled = launchedAt.addingTimeInterval(-settleAge)
        return Set(files.filter { $0.value < settled && URL(filePath: $0.key).pathExtension != "json" && !list.contains($0.key) }.keys)
    }

    /// What a video, a style or a kit saved as JSON says to name an imported family: "custom:Brand Sans", as JSON writes it.
    static func token(for family: String) -> String {
        let encoded = (try? JSONEncoder().encode(TextOverlayFont.custom(family).rawValue)).flatMap { String(bytes: $0, encoding: .utf8) }
        return encoded.map { String($0.dropFirst().dropLast()) } ?? TextOverlayFont.custom(family).rawValue
    }

    /// The removed families nothing in `saved` names.
    static func unusedFonts(_ removed: [String], saved: String) -> Set<String> {
        Set(removed.filter { !saved.contains(token(for: $0)) && !saved.contains(TextOverlayFont.custom($0).rawValue) })
    }

    /// Removes a folder's strays (`strays`): its list is `listName` inside it.
    static func sweep(_ folder: URL, listName: String, launchedAt: Date) {
        let files = EditStorageCleaner.modified(in: folder)
        guard !files.isEmpty else { return }
        let listURL = folder.appending(path: listName)
        let list: String
        if FileManager.default.fileExists(atPath: listURL.path(percentEncoded: false)) {
            // A list that can't be read now (the iPhone locked, a damaged file) might name any of them.
            guard let data = try? Data(contentsOf: listURL), let text = String(bytes: data, encoding: .utf8) else { return }
            list = text
        } else {
            list = ""
        }
        for name in strays(files: files, list: list, launchedAt: launchedAt) {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    /// Everything saved that could name a font: every JSON under Application Support but the fonts' own list, and `styles`
    /// (`savedStyles`). Nil when a file can't be read now.
    static func savedText(support: URL = .applicationSupportDirectory, fonts: URL = CustomFontFiles.directory, styles: String) -> String? {
        EditStorageCleaner.savedText(in: support, skipping: fonts).map { $0 + styles }
    }

    /// The saved styles, kept in the settings, as text.
    static func savedStyles(in defaults: UserDefaults) -> String {
        let keys = [
            DefaultsKey.captionStyleLibrary, DefaultsKey.textStyleLibrary, DefaultsKey.coverStyleLibrary, DefaultsKey.myCaptionStyle,
            DefaultsKey.myTextStyle, DefaultsKey.myCoverStudioStyle,
        ]
        return keys.compactMap { defaults.data(forKey: $0).flatMap { String(bytes: $0, encoding: .utf8) } }.joined()
    }
}
