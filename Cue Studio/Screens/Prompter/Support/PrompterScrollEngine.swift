//
//  PrompterScrollEngine.swift
//  Cue Studio
//

import Foundation

/// Scroll position of the prompter text. The first line starts on the reading guide; the end is
/// reached when the last line gets there.
nonisolated struct PrompterScrollEngine: Equatable, Sendable {
    private(set) var offset: Double = 0
    private(set) var contentHeight: Double = 0
    private(set) var lineHeight: Double = 0
    private(set) var wordCount = 0

    var endOffset: Double { max(0, contentHeight - lineHeight) }

    var progress: Double { endOffset > 0 ? min(1, offset / endOffset) : 0 }

    var isAtEnd: Bool { endOffset > 0 && offset >= endOffset - 0.5 }

    mutating func updateLayout(contentHeight: Double, lineHeight: Double, wordCount: Int) {
        self.contentHeight = max(0, contentHeight)
        self.lineHeight = max(0, lineHeight)
        self.wordCount = max(0, wordCount)
        offset = min(offset, endOffset)
    }

    /// Scroll speed in points per second. Calibrated from the text's own density so that 1.0×
    /// reads at the same pace the read-time estimates assume, whatever the font size or margins.
    func pointsPerSecond(speed: Double) -> Double {
        guard wordCount > 0, contentHeight > 0 else { return 0 }
        let wordsPerSecond = ReadTime.wordsPerMinute(speed: speed) / 60
        return wordsPerSecond * contentHeight / Double(wordCount)
    }

    /// Moves forward by `seconds` of reading. Returns true when this step reached the end.
    @discardableResult
    mutating func advance(by seconds: Double, speed: Double) -> Bool {
        guard !isAtEnd, seconds > 0 else { return false }
        offset = min(endOffset, offset + pointsPerSecond(speed: speed) * seconds)
        return isAtEnd
    }

    /// How quickly Voice follow catches up with the reader by default: about two thirds of the way
    /// in this many seconds. Recognition arrives in bursts of a word or two; easing turns them
    /// into a steady scroll. `VoiceGlide` picks a time for each correction.
    static let glideTime: Double = 0.35

    /// Eases toward `target` for Voice follow, never backward: about two thirds of the way in
    /// `glideTime` seconds. Returns true when this step reached the end.
    @discardableResult
    mutating func glide(toward target: Double, by seconds: Double, glideTime: Double = Self.glideTime) -> Bool {
        guard !isAtEnd, seconds > 0, glideTime > 0 else { return false }
        let goal = min(endOffset, target)
        guard goal > offset else { return false }
        let remaining = (goal - offset) * exp(-seconds / glideTime)
        offset = remaining < 0.5 ? goal : goal - remaining
        return isAtEnd
    }

    /// Puts the text at `offset` (a layout changed under it), within the text.
    mutating func seek(to offset: Double) {
        self.offset = min(endOffset, max(0, offset))
    }

    /// Positive moves the text up (forward).
    mutating func scroll(by delta: Double) {
        offset = min(endOffset, max(0, offset + delta))
    }

    mutating func jump(lines: Int) {
        scroll(by: Double(lines) * lineHeight)
    }

    mutating func rewind() {
        offset = 0
    }
}
