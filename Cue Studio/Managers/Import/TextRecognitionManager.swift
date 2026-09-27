//
//  TextRecognitionManager.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import Vision

/// Vision text recognition for "Scan" and "Photo" imports. Nothing leaves the device.
@MainActor
@Observable
final class TextRecognitionManager: TextRecognizing {
    func recognizeText(in images: [CGImage]) async throws -> ImportedDocument {
        var pages: [String] = []
        for image in images {
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            request.usesLanguageCorrection = true
            let observations = try await request.perform(on: image)
            let lines = observations.compactMap { observation -> RecognizedLine? in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                // Vision boxes are normalized with the origin at the bottom left.
                let box = observation.boundingBox.cgRect
                return RecognizedLine(text: text, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
            }
            pages.append(OCRTextLayout.text(from: lines))
        }
        let text = ScriptTextNormalizer.normalize(pages.filter { !$0.isEmpty }.joined(separator: "\n\n"))
        guard !text.isEmpty else { throw DocumentImportError.noText }
        return ImportedDocument(
            title: ScriptTextNormalizer.suggestedTitle(fileName: nil, text: text),
            text: text,
            kind: String(localized: "Photo")
        )
    }
}
