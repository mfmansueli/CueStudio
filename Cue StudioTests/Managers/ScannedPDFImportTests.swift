//
//  ScannedPDFImportTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// A PDF without a text layer is read like photos: its first pages, drawn off the main thread, and the sheet says when the file
/// has more pages than were read.
@MainActor
@Suite("Scanned PDF import")
struct ScannedPDFImportTests {
    /// A PDF of `pages` pages with only shapes on them (no text layer), as a scanner makes.
    private func scannedPDF(pages: Int) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "scan-\(UUID().uuidString).pdf")
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 400)
        try UIGraphicsPDFRenderer(bounds: bounds).writePDF(to: url) { context in
            for _ in 0..<pages {
                context.beginPage()
                UIColor.black.setFill()
                context.fill(CGRect(x: 40, y: 40, width: 200, height: 20))
            }
        }
        return url
    }

    @Test func aLongScanSaysHowManyPagesWereRead() async throws {
        let url = try scannedPDF(pages: 12)
        defer { try? FileManager.default.removeItem(at: url) }
        let pages = await DocumentImportService().pageImages(ofPDFAt: url, maxPages: 10)
        #expect(pages.images.count == 10)
        #expect(pages.pageCount == 12)
        #expect(pages.unreadNote == "Pages read: 10 of 12")
    }

    @Test func aScanReadWholeSaysNothing() async throws {
        let url = try scannedPDF(pages: 3)
        defer { try? FileManager.default.removeItem(at: url) }
        let pages = await DocumentImportService().pageImages(ofPDFAt: url, maxPages: 10)
        #expect(pages.images.count == 3)
        #expect(pages.unreadNote == nil)
    }
}
