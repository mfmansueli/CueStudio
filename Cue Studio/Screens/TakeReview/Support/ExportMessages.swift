//
//  ExportMessages.swift
//  Cue Studio
//

import Foundation

/// What a finished export says (SHARING.md §2), with the free exports left after it ("· 2 of 3 free exports left"); `left` is nil on Pro, which
/// has no count to tell. Nothing here says "posted": no platform tells Cue that.
nonisolated enum ExportMessages {
    /// "Ready to post on TikTok": saved, with the app open for the creator to pick it.
    static func ready(on platform: String, left: Int?, limit: Int) -> String {
        withLeft(String(localized: "Ready to post on \(platform)"), left: left, limit: limit)
    }

    /// "Opened Reels with your video · Cue can't see if you post it".
    static func opened(_ platform: String, left: Int?, limit: Int) -> String {
        withLeft(String(localized: "Opened \(platform) with your video · Cue can’t see if you post it"), left: left, limit: limit)
    }

    /// "Saved to Photos · Open LinkedIn to post it".
    static func savedForPosting(on platform: String, left: Int?, limit: Int) -> String {
        withLeft(String(localized: "Saved to Photos · Open \(platform) to post it"), left: left, limit: limit)
    }

    /// "Shared with TikTok", or "Shared" when the creator picked another app.
    static func shared(with platform: String?, left: Int?, limit: Int) -> String {
        withLeft(platform.map { String(localized: "Shared with \($0)") } ?? String(localized: "Shared"), left: left, limit: limit)
    }

    private static func withLeft(_ message: String, left: Int?, limit: Int) -> String {
        guard let left else { return message }
        return message + " · " + String(localized: "\(left) of \(limit) free exports left")
    }
}
