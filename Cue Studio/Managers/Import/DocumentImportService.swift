//
//  DocumentImportService.swift
//  Cue Studio
//

import PDFKit
import UIKit
import UniformTypeIdentifiers

/// Reads .txt, .md, .rtf, .html, .pdf and .fountain files. Google Docs and Notion reach Cue through
/// the Files app (exported documents) or the clipboard.
@MainActor
@Observable
final class DocumentImportService: DocumentImporting {
    let supportedTypes: [UTType] = [
        .plainText, .utf8PlainText, .rtf, .rtfd, .html, .pdf,
        UTType(filenameExtension: "md") ?? .plainText,
        UTType(filenameExtension: "fountain") ?? .plainText,
    ]

    func importDocument(at url: URL) throws -> ImportedDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        let raw: String
        switch ext {
        case "pdf":
            guard let document = PDFDocument(url: url) else { throw DocumentImportError.unreadable }
            raw = ScriptTextNormalizer.normalize(document.string ?? "", joinWrappedLines: true)
        case "rtf", "rtfd":
            raw = ScriptTextNormalizer.normalize(try attributedText(at: url, type: .rtf))
        case "html", "htm":
            raw = ScriptTextNormalizer.normalize(try attributedText(at: url, type: .html))
        case "fountain":
            raw = ScriptTextNormalizer.normalizeFountain(try plainText(at: url))
        default:
            raw = ScriptTextNormalizer.normalize(try plainText(at: url))
        }
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DocumentImportError.noText }
        return ImportedDocument(
            title: ScriptTextNormalizer.suggestedTitle(fileName: url.lastPathComponent, text: raw),
            text: raw,
            kind: ext.isEmpty ? "TXT" : ext.uppercased()
        )
    }

    func clipboardText() -> String? {
        guard UIPasteboard.general.hasStrings, let string = UIPasteboard.general.string else { return nil }
        let text = ScriptTextNormalizer.normalize(string)
        return text.isEmpty ? nil : text
    }

    // MARK: - Readers

    private func plainText(at url: URL) throws -> String {
        var encoding = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &encoding) { return text }
        if let text = try? String(contentsOf: url, encoding: .isoLatin1) { return text }
        throw DocumentImportError.unreadable
    }

    private func attributedText(at url: URL, type: NSAttributedString.DocumentType) throws -> String {
        do {
            return try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil).string
        } catch {
            throw DocumentImportError.unreadable
        }
    }
}
