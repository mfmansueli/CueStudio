//
//  FontPackFiles.swift
//  Cue Studio
//

import CoreText
import CryptoKit
import Foundation
import UIKit

/// The library files downloaded on this iPhone, in Application Support/FontPacks (one folder per family), kept out of the
/// iCloud backup (they can always be downloaded again). Each is registered with Core Text for Cue alone (never for other apps)
/// and checked against the SHA-256 the manifest gives before it is kept.
nonisolated enum FontPackFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "FontPacks", directoryHint: .isDirectory)
    }

    static func url(of pack: FontPack, _ file: FontPack.File, in folder: URL = directory) -> URL {
        folder.appending(path: pack.id, directoryHint: .isDirectory).appending(path: file.file)
    }

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    /// Whether `data` is the file the manifest names.
    static func matches(_ data: Data, _ file: FontPack.File) -> Bool {
        guard data.count == file.bytes else { return false }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == file.sha256.lowercased()
    }

    /// Writes a checked file in place, its folder kept out of the backup.
    static func keep(_ data: Data, at url: URL, root: URL = directory) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var folder = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
        try data.write(to: url, options: .atomic)
    }

    /// Registers the file for this launch; true when Core Text draws a face of that name (registered now or before, or the
    /// same face already on this iPhone: the creator imported it too).
    @discardableResult
    static func register(_ url: URL, postScriptName: String) -> Bool {
        var error: Unmanaged<CFError>?
        let done = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        error?.release()
        return done || UIFont(name: postScriptName, size: 12) != nil
    }

    static func unregister(_ url: URL) {
        var error: Unmanaged<CFError>?
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &error)
        error?.release()
    }

    /// Deletes a family's folder (its files unregistered first).
    static func remove(_ pack: FontPack, in folder: URL = directory) {
        for file in pack.files { unregister(url(of: pack, file, in: folder)) }
        try? FileManager.default.removeItem(at: folder.appending(path: pack.id, directoryHint: .isDirectory))
    }

    /// "Delete my Cue data": every downloaded file.
    static func removeAll(in folder: URL = directory) {
        let families = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for family in families {
            let files = (try? FileManager.default.contentsOfDirectory(at: family, includingPropertiesForKeys: nil)) ?? []
            for file in files { unregister(file) }
        }
        try? FileManager.default.removeItem(at: folder)
    }
}
