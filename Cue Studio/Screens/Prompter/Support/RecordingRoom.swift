//
//  RecordingRoom.swift
//  Cue Studio
//

import Foundation

/// How many minutes of video still fit on the iPhone in the format the camera records, and the quiet line the recorder shows once the room
/// runs low ("About 9 min left in 4K"). Below `threshold` free; above it, nothing is said (iOS already shows the app's storage).
nonisolated enum RecordingRoom {
    /// Free space under which the recorder says how much video still fits: about 2 GB.
    static let threshold: Int64 = 2_000_000_000

    /// About how many megabytes a minute of video takes: what the iPhone's camera writes in HEVC at 30 fps (720p 25, 1080p 60, 4K 170),
    /// more at 60 fps and less at 24, and H.264 about 1.75 times as much. Rounded up a little, so the minutes promised are there.
    static func megabytesPerMinute(resolution: VideoResolution, frameRate: FrameRate, codec: VideoCodec) -> Double {
        let base: Double = switch resolution {
        case .hd720: 25
        case .hd1080: 60
        case .uhd4K: 170
        }
        let rate: Double = switch frameRate {
        case .fps24: 0.8
        case .fps30: 1
        case .fps60: 1.5
        }
        return base * rate * (codec == .h264 ? 1.75 : 1)
    }

    /// Whole minutes of video `available` bytes still hold; nil when the space can't be read.
    static func minutesLeft(available: Int64?, resolution: VideoResolution, frameRate: FrameRate, codec: VideoCodec) -> Int? {
        guard let available else { return nil }
        let room = max(0, Double(available - StorageSpace.margin)) / 1_000_000
        return Int(room / megabytesPerMinute(resolution: resolution, frameRate: frameRate, codec: codec))
    }

    /// "About 9 min left in 4K", while less than `threshold` is free; nil otherwise (or when the space can't be read).
    static func notice(available: Int64?, resolution: VideoResolution, frameRate: FrameRate, codec: VideoCodec) -> String? {
        guard let available, available < threshold,
              let minutes = minutesLeft(available: available, resolution: resolution, frameRate: frameRate, codec: codec) else { return nil }
        guard minutes >= 1 else { return String(localized: "Less than 1 min left in \(resolution.label)") }
        return String(localized: "About \(minutes) min left in \(resolution.label)")
    }
}
