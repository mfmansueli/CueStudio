//
//  WritingFileReader.swift
//  Cue Studio
//

import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Reads the text of the files the creator opens to import their writing: plain text and Markdown, rich text and PDF. Anything else, or a file
/// that is too big or has no text, is skipped and counted, never an error that stops the rest.
nonisolated enum WritingFileReader {
    /// The kinds of file the picker offers.
    static var contentTypes: [UTType] {
        [.plainText, .utf8PlainText, .rtf, .pdf] + (UTType(filenameExtension: "md").map { [$0] } ?? [])
    }

    /// A file bigger than this is not a script.
    static let largestFile = 2_000_000

    struct Result: Sendable {
        var pieces: [WritingPiece] = []
        /// Files that could not be read or held no text.
        var skipped = 0
    }

    /// The texts in `urls` (each file may hold several, separated by lines of `---`).
    static func read(_ urls: [URL]) -> Result {
        var result = Result()
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let found = text(at: url).map { WritingCleaner.pieces(from: $0, source: url.deletingPathExtension().lastPathComponent) } ?? []
            if found.isEmpty { result.skipped += 1 }
            result.pieces += found
        }
        return result
    }

    static func text(at url: URL) -> String? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size <= largestFile else { return nil }
        switch url.pathExtension.lowercased() {
        case "pdf": return PDFDocument(url: url)?.string
        case "rtf", "rtfd":
            return (try? NSAttributedString(url: url, options: [:], documentAttributes: nil))?.string
        default:
            var encoding = String.Encoding.utf8
            return try? String(contentsOf: url, usedEncoding: &encoding)
        }
    }
}
