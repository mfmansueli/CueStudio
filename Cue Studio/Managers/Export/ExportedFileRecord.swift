//
//  ExportedFileRecord.swift
//  Cue Studio
//

import Darwin
import Foundation

/// What an exported file was drawn with (`ExportRenderStamp`) and whether some of its words came out in the system's face, kept on the
/// file itself (an extended attribute): it goes where the file goes and is gone with it, survives Cue closing, and a file without one
/// (made by an older Cue, or the attribute couldn't be written) is never reused for a retry, since what it holds can't be known.
nonisolated struct ExportedFileRecord: Codable, Equatable, Sendable {
    static let attribute = "studio.cue.export"

    var renderStamp: String
    var fontFallback: ExportFontFallback?

    /// The record of the file at `url`, nil when it has none (or isn't there).
    static func read(at url: URL) -> ExportedFileRecord? {
        let path = url.path(percentEncoded: false)
        let size = getxattr(path, attribute, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, attribute, $0.baseAddress, size, 0, 0) }
        guard read == size else { return nil }
        return try? JSONDecoder().decode(ExportedFileRecord.self, from: data)
    }

    /// Keeps the record on the file at `url`; false when it couldn't (then the file is simply never reused).
    @discardableResult
    func write(to url: URL) -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        let path = url.path(percentEncoded: false)
        return data.withUnsafeBytes { setxattr(path, Self.attribute, $0.baseAddress, data.count, 0, 0) } == 0
    }
}
