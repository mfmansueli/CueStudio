//
//  RecordingRoomTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The recorder's storage line: said only below about 2 GB free, in minutes of the format the camera records.
@Suite("RecordingRoom")
struct RecordingRoomTests {
    private func notice(_ bytes: Int64?, _ resolution: VideoResolution = .uhd4K, codec: VideoCodec = .hevc) -> String? {
        RecordingRoom.notice(available: bytes, resolution: resolution, frameRate: .fps30, codec: codec)
    }

    @Test func plentyOfRoomSaysNothing() {
        #expect(notice(RecordingRoom.threshold) == nil)
        #expect(notice(50_000_000_000) == nil)
        #expect(notice(nil) == nil)
    }

    @Test func lowRoomSaysTheMinutesInTheFormatRecorded() {
        // 1.68 GB free, 150 MB kept aside: 1,530 MB, 9 min of 4K at 170 MB a minute.
        #expect(notice(1_680_000_000) == "About 9 min left in 4K")
        #expect(notice(1_680_000_000, .hd1080) == "About 25 min left in 1080p")
    }

    @Test func heavierFormatsHoldFewerMinutes() {
        let hevc = RecordingRoom.minutesLeft(available: 1_500_000_000, resolution: .hd1080, frameRate: .fps30, codec: .hevc) ?? 0
        let h264 = RecordingRoom.minutesLeft(available: 1_500_000_000, resolution: .hd1080, frameRate: .fps30, codec: .h264) ?? 0
        let sixty = RecordingRoom.minutesLeft(available: 1_500_000_000, resolution: .hd1080, frameRate: .fps60, codec: .hevc) ?? 0
        #expect(h264 < hevc)
        #expect(sixty < hevc)
    }

    @Test func underAMinuteSaysSo() {
        #expect(notice(200_000_000) == "Less than 1 min left in 4K")
        #expect(notice(100_000_000) == "Less than 1 min left in 4K")
    }
}
