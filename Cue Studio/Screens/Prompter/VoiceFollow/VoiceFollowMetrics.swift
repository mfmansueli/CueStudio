//
//  VoiceFollowMetrics.swift
//  Cue Studio
//

import Foundation

/// How quickly Voice Following reacts on this device, measured while it runs, for tuning. Kept in
/// memory and, in debug builds, written to the device's own log when a session ends. Nothing is
/// sent anywhere: no audio, no transcript and no number leaves the iPhone.
///
/// - Startup: from turning Voice Following on to listening, and to the first words heard; whether
///   the language had to download first.
/// - Speech onset: from the buffer where the voice began to the indicator lighting, and to the
///   text's first move.
/// - Alignment: from a transcription arriving to the text knowing where to go.
/// - Prediction: how far ahead of the words the text had run when recognition confirmed them.
/// - False starts: stretches of "speaking" in which nothing was recognized at all.
nonisolated struct VoiceFollowMetrics: Equatable, Sendable {
    /// Seconds from turning Voice Following on until it listened.
    private(set) var startup: TimeInterval?
    /// Seconds from turning Voice Following on until the first words were recognized.
    private(set) var firstWords: TimeInterval?
    /// The start waited on a download of the language's model.
    private(set) var downloaded = false

    private(set) var onsetToIndicator: [TimeInterval] = []
    private(set) var onsetToMovement: [TimeInterval] = []
    private(set) var alignment: [TimeInterval] = []
    /// Words the text was ahead of what recognition then confirmed (0 when it wasn't).
    private(set) var overshoot: [Double] = []
    private(set) var onsets = 0
    private(set) var falseOnsets = 0

    private var enabledAt: TimeInterval?
    private var lastTranscript = ""
    /// The onset still waiting for the text to move.
    private var waitingToMove: TimeInterval?
    /// Something was recognized during the current stretch of speaking.
    private var heardWords = false
    private var isSpeaking = false

    /// Samples kept per measure; older ones make room.
    static let sampleLimit = 500

    // MARK: - Events

    mutating func enabled(at time: TimeInterval) {
        self = VoiceFollowMetrics()
        enabledAt = time
    }

    mutating func downloading() {
        downloaded = true
    }

    mutating func listening(at time: TimeInterval) {
        startup = enabledAt.map { time - $0 }
    }

    /// A transcription arrived at `received`; the text knew where to go at `aligned`.
    mutating func transcript(_ text: String, receivedAt received: TimeInterval, alignedAt aligned: TimeInterval) {
        Self.append(aligned - received, to: &alignment)
        guard text != lastTranscript else { return }
        lastTranscript = text
        heardWords = true
        if firstWords == nil, text.contains(where: { $0.isLetter || $0.isNumber }) {
            firstWords = enabledAt.map { received - $0 }
        }
    }

    /// The indicator changed: speech began (or ended) in the buffer that arrived at `heard`, and
    /// the creator saw it at `shown`.
    mutating func voice(_ speaking: Bool, heardAt heard: TimeInterval, shownAt shown: TimeInterval) {
        if speaking {
            onsets += 1
            heardWords = false
            waitingToMove = heard
            Self.append(shown - heard, to: &onsetToIndicator)
        } else if isSpeaking, !heardWords {
            falseOnsets += 1
        }
        isSpeaking = speaking
    }

    /// The text moved on a frame at `time`.
    mutating func moved(at time: TimeInterval) {
        guard let onset = waitingToMove else { return }
        waitingToMove = nil
        Self.append(time - onset, to: &onsetToMovement)
    }

    /// Recognition confirmed a word while the text was `ahead` words past it.
    mutating func confirmed(ahead: Double) {
        Self.append(max(0, ahead), to: &overshoot)
    }

    // MARK: - Reading

    /// The value `fraction` of the way through `values` (0.5 is the median, 0.95 the 95th
    /// percentile). Nil when there's nothing measured.
    static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * min(1, max(0, fraction))).rounded())
        return sorted[index]
    }

    /// One line for the log.
    var summary: String {
        func timing(_ values: [Double]) -> String {
            guard let median = Self.percentile(values, 0.5), let high = Self.percentile(values, 0.95) else { return "–" }
            return "p50 \(Self.milliseconds(median)) p95 \(Self.milliseconds(high)) (n=\(values.count))"
        }
        let words = Self.percentile(overshoot, 0.95).map { String(format: "%.1f", $0) } ?? "–"
        return "startup \(startup.map(Self.milliseconds) ?? "–")\(downloaded ? " (downloaded)" : "")"
            + " · first words \(firstWords.map(Self.milliseconds) ?? "–")"
            + " · onset→indicator \(timing(onsetToIndicator)) · onset→move \(timing(onsetToMovement))"
            + " · transcript→aligned \(timing(alignment)) · ahead p95 \(words) words"
            + " · false starts \(falseOnsets)/\(onsets)"
    }

    private static func milliseconds(_ seconds: TimeInterval) -> String {
        "\(Int((seconds * 1000).rounded())) ms"
    }

    private static func append(_ value: Double, to values: inout [Double]) {
        values.append(value)
        if values.count > sampleLimit { values.removeFirst(values.count - sampleLimit) }
    }
}
