//
//  ExportFileName.swift
//  Cue Studio
//

import Foundation

/// The name an exported video carries into Files, AirDrop, Mail or a computer: the script's title and the take ("Morning routine · Take 2.mov"),
/// never a random id. Each file sits in a folder of its own, named after the exporter's random one, so two videos of one take never share a
/// path and a file that went is never mistaken for a later one (`ExportLedgerService` keeps the path inside its folder).
nonisolated enum ExportFileName {
    /// Longest title kept, in characters: Files and Mail show about this much.
    static let maxTitleLength = 60

    /// The file name for a take, without the folder.
    static func name(title: String, takeNumber: Int) -> String {
        "\(sanitized(title)) · \(String(localized: "Take \(takeNumber)")).mov"
    }

    /// A title that every file system takes: no slashes, colons or control characters, one line, trimmed, at most `maxTitleLength`; an empty
    /// one is "Cue video".
    static func sanitized(_ title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters).union(.newlines)
        let cleaned = title.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        let short = String(cleaned.prefix(maxTitleLength)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? String(localized: "Cue video") : short
    }

    /// Moves the exporter's file (`Cue-xxxxxxxx.mov`) to `Cue-xxxxxxxx/<name>` next to it, keeping its extended attributes
    /// (`ExportedFileRecord`). The original URL when the move fails: a random name is better than no video.
    static func rename(_ url: URL, title: String, takeNumber: Int, files: FileManager = .default) -> URL {
        let folder = url.deletingPathExtension()
        let target = folder.appending(path: name(title: title, takeNumber: takeNumber))
        do {
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            try files.moveItem(at: url, to: target)
            return target
        } catch {
            try? files.removeItem(at: folder)
            return url
        }
    }
}
