// Reads the text in screenshots with Vision and prints one JSON object per picture:
//   {"file": "<path>", "width": <px>, "height": <px>, "lines": [{"text": "...", "x": .., "y": .., "w": .., "h": .., "confidence": ..}]}
// Boxes are in pixels from the top left. Used by tools/layout/truncation.py (compile once: swiftc -O tools/layout/ocr.swift -o <bin>).
//
//   ocr <language,language,...> <picture.png> [<picture.png> ...]

import AppKit
import Foundation
import Vision

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: ocr <languages> <picture.png>...\n".utf8))
    exit(64)
}
let languages = arguments[1].split(separator: ",").map(String.init)

for path in arguments.dropFirst(2) {
    guard let image = NSImage(contentsOfFile: path),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        FileHandle.standardError.write(Data("can't read \(path)\n".utf8))
        continue
    }
    let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = languages
    request.minimumTextHeight = 0.008
    try? VNImageRequestHandler(cgImage: cgImage).perform([request])
    var lines: [[String: Any]] = []
    for observation in request.results ?? [] {
        guard let candidate = observation.topCandidates(1).first else { continue }
        let box = observation.boundingBox
        lines.append([
            "text": candidate.string,
            "x": Double(box.minX * width), "y": Double((1 - box.maxY) * height),
            "w": Double(box.width * width), "h": Double(box.height * height),
            "confidence": Double(candidate.confidence),
        ])
    }
    let object: [String: Any] = ["file": path, "width": Double(width), "height": Double(height), "lines": lines]
    if let data = try? JSONSerialization.data(withJSONObject: object), let line = String(data: data, encoding: .utf8) {
        print(line)
    }
}
