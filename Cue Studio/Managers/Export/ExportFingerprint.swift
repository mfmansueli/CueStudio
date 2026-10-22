//
//  ExportFingerprint.swift
//  Cue Studio
//

import CryptoKit
import Foundation

/// A stable name for "this take, this edit, these export settings": an exported file is reused for a retry only while
/// the fingerprint is the same, so changing anything (a trim, the captions, the quality, the recording) never brings back
/// stale output. `Hashable.hashValue` can't do this job: it is different on every launch.
nonisolated enum ExportFingerprint {
    static func make(takeID: UUID, source: URL, options: ExportOptions) -> String {
        var parts: [String] = [
            takeID.uuidString,
            options.aspect.rawValue,
            "captions:\(options.burnsInCaptions)",
            "short:\(options.shortSide.map { String(Double($0)) } ?? "-")",
            "fps:\(options.frameRate.map { String($0) } ?? "-")",
            sourceStamp(of: source),
        ]
        if let edit = options.edit {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .secondsSince1970
            parts.append((try? encoder.encode(edit)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "edit")
        } else {
            parts.append("no-edit")
        }
        let digest = SHA256.hash(data: Data(parts.joined(separator: "\u{1F}").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The recording's size and modification time: a different file under the same name is a different export. (Read with
    /// `FileManager`: `URL.resourceValues` caches what it read.)
    private static func sourceStamp(of url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }
}
