//
//  BrandKitFiles.swift
//  Cue Studio
//

import Foundation

/// The brand kits (`kits.json`) and their logos, in Application Support/BrandKits, on this iPhone only. A kit's logo is its
/// own link to the picture's bytes: deleting it from the library, or from a video, leaves the kit whole.
nonisolated enum BrandKitFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "BrandKits", directoryHint: .isDirectory)
    }

    static func url(for fileName: String, in folder: URL = directory) -> URL {
        folder.appending(path: fileName)
    }

    /// "Delete my Cue data": the folder whole.
    static func removeAll(in folder: URL = directory) {
        try? FileManager.default.removeItem(at: folder)
    }
}
