//
//  TextRecognizing.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Reads printed text from photos and scans (a brand's brief, a printed script). Runs on the device.
protocol TextRecognizing: AnyObject {
    func recognizeText(in images: [CGImage]) async throws -> ImportedDocument
}
