//
//  CustomFontFiles.swift
//  Cue Studio
//

import CoreText
import Foundation

/// The creator's imported font files, in Application Support/Fonts (with `fonts.json`, the families), on this iPhone only.
/// Each is registered with Core Text for Cue alone (never for other apps) and never moved while registered. Videos name a
/// family, never a file.
nonisolated enum CustomFontFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Fonts", directoryHint: .isDirectory)
    }

    static func url(for fileName: String, in folder: URL = directory) -> URL {
        folder.appending(path: fileName)
    }

    /// Registers the file for this launch; false when Core Text refuses it (a name taken meanwhile, a file gone).
    @discardableResult
    static func register(_ url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let done = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        error?.release()
        return done
    }

    static func unregister(_ url: URL) {
        var error: Unmanaged<CFError>?
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &error)
        error?.release()
    }

    /// "Delete my Cue data": unregistered, then the folder whole.
    static func removeAll(in folder: URL = directory) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension != "json" { unregister(file) }
        try? FileManager.default.removeItem(at: folder)
    }
}
