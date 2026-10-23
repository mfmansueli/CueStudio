//
//  NarrationScriptPace.swift
//  Cue Studio
//

import Foundation

/// How far the script shown over the preview while a voice-over records has been read: at a steady pace (the prompter's
/// words a minute, `ReadTime`) from the moment the recording starts, held by a tap and going on from there by another. Kept in
/// words, not points, so a new layout (another preview size) keeps the place. It never follows the voice: the microphone is
/// recording the narration.
nonisolated struct NarrationScriptPace: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// Before the recording: the start of the script shows.
        case waiting
        case reading(since: Date)
        case paused
    }

    private(set) var phase: Phase = .waiting
    /// Words read until the last start, pause or change of speed.
    private(set) var banked: Double = 0
    /// On `PrompterSettings.speed`'s scale (1× is `ReadTime.naturalSpeed`).
    private(set) var speed: Double

    init(speed: Double = ReadTime.naturalSpeed) {
        self.speed = PrompterSettings.clampedSpeed(speed)
    }

    var isReading: Bool {
        if case .reading = phase { true } else { false }
    }

    var isPaused: Bool { phase == .paused }

    /// The recording started: from the first word.
    mutating func start(at now: Date) {
        banked = 0
        phase = .reading(since: now)
    }

    /// A tap: holds the text where it is, or goes on from there. Nothing before the recording starts.
    mutating func togglePause(at now: Date) {
        switch phase {
        case .waiting: return
        case .reading:
            banked = wordsRead(at: now)
            phase = .paused
        case .paused:
            phase = .reading(since: now)
        }
    }

    /// A new speed from now on; what was read stays read.
    mutating func setSpeed(_ newSpeed: Double, at now: Date) {
        if case .reading = phase {
            banked = wordsRead(at: now)
            phase = .reading(since: now)
        }
        speed = PrompterSettings.clampedSpeed(newSpeed)
    }

    /// The recording ended: back to the start.
    mutating func reset() {
        banked = 0
        phase = .waiting
    }

    func wordsRead(at now: Date) -> Double {
        guard case .reading(let since) = phase else { return banked }
        return banked + max(0, now.timeIntervalSince(since)) * ReadTime.wordsPerMinute(speed: speed) / 60
    }

    /// How far up the text is moved after `wordsRead` of its `wordCount` words, in points: the prompter's calibration (a word is
    /// `contentHeight / wordCount` points, `PrompterScrollEngine.pointsPerSecond`), never past the last line at the top. With
    /// `stepsByLine` (Reduce Motion) it moves a whole line at a time instead of gliding.
    static func offset(wordsRead: Double, wordCount: Int, contentHeight: Double, lineHeight: Double, stepsByLine: Bool) -> Double {
        guard wordCount > 0, contentHeight > 0 else { return 0 }
        var engine = PrompterScrollEngine()
        engine.updateLayout(contentHeight: contentHeight, lineHeight: lineHeight, wordCount: wordCount)
        engine.seek(to: max(0, wordsRead) * contentHeight / Double(wordCount))
        guard stepsByLine, lineHeight > 0 else { return engine.offset }
        return (engine.offset / lineHeight).rounded(.down) * lineHeight
    }

    /// The text's size over a preview area `size` big: large for it (7% of its width, or 8% of its height when the area is short),
    /// never under 17 points nor over the prompter's own size.
    static func fontSize(forPreview size: CGSize, prompterSize: Double) -> Double {
        let fitted = min(size.width * 0.07, size.height * 0.08)
        return min(max(17, prompterSize), max(17, fitted.rounded()))
    }
}
