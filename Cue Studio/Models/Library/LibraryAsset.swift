//
//  LibraryAsset.swift
//  Cue Studio
//

import Foundation

/// A file the creator keeps to reuse across videos: its name (theirs to change), what it is, its file in `MediaLibraryFiles`,
/// its shape and length, whether it's a favorite, and a fingerprint of its bytes so the same file is never kept twice. A
/// video that uses it has its own link to the same bytes (`EditMediaFiles`): removing it from the library never touches a
/// video.
nonisolated struct LibraryAsset: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var kind: LibraryAssetKind
    var fileName: String
    /// Width over height, upright.
    var aspect: Double
    /// A video's length; nil for a picture.
    var duration: TimeInterval?
    var hasSound = false
    var isFavorite = false
    var addedAt = Date.now
    /// Last put in a video: the library shows the latest first.
    var usedAt: Date?
    /// SHA-256 of the file's bytes.
    var fingerprint: String
    var byteCount: Int64 = 0

    /// When it was last added or used.
    var recency: Date { max(addedAt, usedAt ?? addedAt) }

    /// Whether it matches what the creator typed (its name, or what it is: "logo", "video").
    func matches(_ search: String) -> Bool {
        let words = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return true }
        return name.localizedStandardContains(words) || kind.label.localizedStandardContains(words)
    }
}
