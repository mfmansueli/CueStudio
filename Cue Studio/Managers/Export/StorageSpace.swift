//
//  StorageSpace.swift
//  Cue Studio
//

import Foundation

/// How much room an export needs and how much the iPhone has, so a full iPhone is told before the export starts, not after
/// minutes of work.
nonisolated enum StorageSpace {
    /// Kept free on top of what an export needs (the system and Photos need some).
    static let margin: Int64 = 150_000_000

    /// Bytes free for things the creator asked for (what Settings › General › iPhone Storage counts); nil when unknown.
    static func available() -> Int64? {
        let values = try? URL.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// An export of about `megabytes` is written once and copied into Photos: twice its size, and the margin.
    static func needed(forExportOf megabytes: Double) -> Int64 {
        Int64(megabytes * 2 * 1_000_000) + margin
    }

    /// Megabytes still to free, or nil when there is room (or the free space can't be read: the export tries).
    static func shortfall(forExportOf megabytes: Double, available: Int64?) -> Int? {
        guard let available else { return nil }
        let missing = needed(forExportOf: megabytes) - available
        return missing > 0 ? Int((Double(missing) / 1_000_000).rounded(.up)) : nil
    }
}
