//
//  FontPackFile.swift
//  Cue Studio
//

import Foundation

/// One file of a library family (`FontPack`): a weight (or, variable, a range of them).
nonisolated struct FontPackFile: Codable, Hashable, Sendable {
    var file: String
    var url: URL
    /// Checked before the file is kept: a file that doesn't match is thrown away.
    var sha256: String
    var bytes: Int
    /// The name it registers under (a variable file: its default instance).
    var postScriptName: String
    /// Its weight, 100 to 900 (a variable file: its default).
    var weight: Double
    var weightRange: ClosedRange<Double>?

    /// The editor weights it draws.
    var editorWeights: [TextOverlayWeight] {
        if let weightRange { return TextOverlayWeight.editorWeights.filter { weightRange.contains($0.value) } }
        return [TextOverlayWeight.nearest(to: min(weight, 800), in: TextOverlayWeight.editorWeights)]
    }

    private enum CodingKeys: String, CodingKey {
        case file, url, sha256, bytes, postScriptName, weight, weightRange
    }

    init(file: String, url: URL, sha256: String, bytes: Int, postScriptName: String, weight: Double, weightRange: ClosedRange<Double>? = nil) {
        self.file = file
        self.url = url
        self.sha256 = sha256
        self.bytes = bytes
        self.postScriptName = postScriptName
        self.weight = weight
        self.weightRange = weightRange
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        file = try container.decode(String.self, forKey: .file)
        url = try container.decode(URL.self, forKey: .url)
        sha256 = try container.decode(String.self, forKey: .sha256)
        bytes = try container.decode(Int.self, forKey: .bytes)
        postScriptName = try container.decode(String.self, forKey: .postScriptName)
        weight = try container.decode(Double.self, forKey: .weight)
        if let range = try container.decodeIfPresent([Double].self, forKey: .weightRange), range.count == 2, range[0] <= range[1] {
            weightRange = range[0]...range[1]
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(file, forKey: .file)
        try container.encode(url, forKey: .url)
        try container.encode(sha256, forKey: .sha256)
        try container.encode(bytes, forKey: .bytes)
        try container.encode(postScriptName, forKey: .postScriptName)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(weightRange.map { [$0.lowerBound, $0.upperBound] }, forKey: .weightRange)
    }
}
