//
//  QuickEditPreviewLatencyTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// How long a change takes to show in the Quick edit preview, and whether the picture ever leaves
/// the screen, measured on this device with the real player and the preview's view in the app's
/// window. The take decodes like a recording (`TestFootage`) and carries the v10 demo edit
/// (`SampleEdit`: a title, a subtitle and eight caption lines burned in); the playhead sits between
/// two keyframes.
///
/// Reported per change, p50 and max over the runs:
/// - shown: from `show(_:)` until the new picture is drawn (a look, text or caption change: the
///   item's frame at the playhead drawn again; a cut: the new item's picture on screen and the
///   held one let go);
/// - blank: changes during which the layer had no picture and nothing was held over it;
/// - swapped / held: changes that swapped the item, and that held the old picture meanwhile.
///
/// Opt-in and on a device:
/// `TEST_RUNNER_CUE_PREVIEW_LATENCY=1 xcodebuild … -only-testing:"Cue StudioTests/QuickEditPreviewLatencyTests" test`.
@MainActor
@Suite(
    "Quick edit preview latency on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_PREVIEW_LATENCY"] != nil)
)
struct QuickEditPreviewLatencyTests {
    enum Scenario: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case filter = "Filter · 1080p"
        case text = "Text · 1080p"
        case filterOverBlur = "Filter, Blur background · 1080p"
        case filter4K = "Filter · 4K"
        case cut = "Cut · 1080p"

        var testDescription: String { rawValue }
    }

    /// What one change did on screen.
    private struct Change {
        var shown: TimeInterval?
        var wentBlank = false
        var swapped = false
        var held = false
    }

    private static let seconds = 22
    /// Halfway between keyframes (one a second), with the title and the first caption line on
    /// screen.
    private static let playhead: TimeInterval = 2.5
    private static let frameRate: Int32 = 30
    private static let changes = 10

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    @Test(arguments: Scenario.allCases)
    func aChangeShowsInThePreview(_ scenario: Scenario) async throws {
        let is4K = scenario == .filter4K
        let url = try await TestFootage.make(seconds: Self.seconds, width: is4K ? 2160 : 1080, height: is4K ? 3840 : 1920)
        defer { try? FileManager.default.removeItem(at: url) }
        var edit = SampleEdit.make(aspect: .portrait)
        edit.filter = .natural
        if scenario == .filterOverBlur {
            var effect = BackgroundEffect()
            effect.style = .blur
            edit.backgrounds = [RecordingBackground(sourceID: nil, effect: effect)]
        }
        let whole = edit.timeline
        var cut = whole
        // A second after the playhead goes, so the playhead stays where it is.
        cut.remove([TimeSpan(start: 5, end: 6)])

        let player = QuickEditPlayer(videoURL: url, editing: TakeEditService(), audioSession: FakePlaybackAudioSession())
        let view = FrameHoldingPlayerView(frame: CGRect(x: 0, y: 0, width: 216, height: 384))
        view.player = player.avPlayer
        player.addFrameHolder(view) { [weak view] frame in view?.hold(frame) }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        try #require(window != nil, "The preview needs the app's window to draw")
        window?.addSubview(view)
        defer {
            view.removeFromSuperview()
            player.stop()
        }
        let layer = try #require(view.layer as? AVPlayerLayer)
        let target = CMTime(seconds: Self.playhead, preferredTimescale: 600)

        // Opening Quick edit: the sound is pulled out and treated once, then reused.
        let opening = uptime
        player.show(edit)
        try await waitUntil { player.state == .ready && layer.isReadyForDisplay }
        player.seek(to: Self.playhead)
        try await waitUntil { abs(player.avPlayer.currentTime().seconds - target.seconds) < 0.001 }
        let opened = uptime - opening

        var output = attachOutput(to: player.avPlayer.currentItem)
        var results: [Change] = []
        // One change more than measured: the first use of a filter or a text size pays once.
        for change in 0...Self.changes {
            switch scenario {
            case .text:
                edit.texts[0].text = change.isMultiple(of: 2) ? "5 comidas de SP!" : "5 comidas de SP"
            case .cut:
                edit.timeline = change.isMultiple(of: 2) ? cut : whole
            case .filter, .filterOverBlur, .filter4K:
                edit.filter = change.isMultiple(of: 2) ? .cinema : .natural
            }
            let item = player.avPlayer.currentItem
            _ = Self.newFrame(in: output, at: target)
            var result = Change()
            let started = uptime
            player.show(edit)
            while result.shown == nil, uptime - started < 5 {
                let ready = layer.isReadyForDisplay
                if view.isHoldingFrame { result.held = true }
                if !ready, !view.isHoldingFrame { result.wentBlank = true }
                if player.avPlayer.currentItem !== item {
                    result.swapped = true
                    if ready, !view.isHoldingFrame { result.shown = uptime - started }
                } else if let time = Self.newFrame(in: output, at: target), Self.isFrame(time, at: target) {
                    result.shown = uptime - started
                }
                if result.shown == nil { try await Task.sleep(for: .milliseconds(1)) }
            }
            if result.swapped { output = attachOutput(to: player.avPlayer.currentItem) }
            if change > 0 { results.append(result) }
        }
        let shown = results.compactMap(\.shown)
        print(
            "PREVIEW LATENCY \(scenario.rawValue)"
                + " · open \(Self.ms(opened))"
                + " · shown \(Self.stats(shown))"
                + " · blank \(results.filter(\.wentBlank).count)/\(Self.changes)"
                + " · swapped \(results.filter(\.swapped).count)/\(Self.changes)"
                + " · held \(results.filter(\.held).count)/\(Self.changes)"
        )
        #expect(shown.count == Self.changes, "Every change should show")
        #expect(results.allSatisfy { !$0.wentBlank }, "The picture should never leave the screen")
        #expect(results.allSatisfy { $0.swapped == (scenario == .cut) }, "Only new pieces should swap the item")
    }

    // MARK: - Reading

    private func waitUntil(_ condition: () -> Bool) async throws {
        let started = uptime
        while !condition() {
            guard uptime - started < 10 else {
                Issue.record("Timed out")
                return
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    /// An output on the item, to see when it draws a frame.
    private func attachOutput(to item: AVPlayerItem?) -> AVPlayerItemVideoOutput {
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: CVPixelBufferAttributes(
            pixelFormatTypes: [CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA)]
        ))
        item?.add(output)
        return output
    }

    /// The time of a frame the output got since the last look, if any.
    private static func newFrame(in output: AVPlayerItemVideoOutput, at time: CMTime) -> CMTime? {
        guard time.isNumeric, output.hasNewPixelBuffer(forItemTime: time) else { return nil }
        let frame = output.pixelBufferAndDisplayTime(forItemTime: time)
        guard frame.pixelBuffer != nil else { return nil }
        return frame.itemTimeForDisplay.isNumeric ? frame.itemTimeForDisplay : time
    }

    private static func isFrame(_ time: CMTime, at target: CMTime) -> Bool {
        abs(time.seconds - target.seconds) < 0.5 / Double(frameRate)
    }

    private static func stats(_ values: [TimeInterval]) -> String {
        let sorted = values.sorted()
        guard let max = sorted.last else { return "–" }
        return "p50 \(ms(sorted[sorted.count / 2])) max \(ms(max))"
    }

    private static func ms(_ seconds: TimeInterval) -> String {
        "\(Int((seconds * 1000).rounded())) ms"
    }
}
