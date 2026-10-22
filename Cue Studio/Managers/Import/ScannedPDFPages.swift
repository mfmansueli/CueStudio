//
//  ScannedPDFPages.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The pages of a PDF without a text layer, drawn for text recognition (`DocumentImporting.pageImages`), and how many pages the
/// file has: more than were drawn means the rest wasn't read.
nonisolated struct ScannedPDFPages: Sendable {
    let images: [CGImage]
    let pageCount: Int

    /// "Pages read: 10 of 23", when not every page was drawn.
    var unreadNote: String? {
        guard pageCount > images.count, !images.isEmpty else { return nil }
        return String(localized: "Pages read: \(images.count) of \(pageCount)")
    }
}
