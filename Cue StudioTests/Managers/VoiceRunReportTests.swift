//
//  VoiceRunReportTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Prints the numbers of every run kept in `Fixtures/VoiceRuns` (plan §6), side by side, so before and after are read from one place:
/// `scripts/test.sh only "Cue StudioTests/VoiceRunReportTests"` and look for the `VOICE REPORT` lines. It judges nothing: what the targets are
/// (zero violations of what they asked to avoid and of "I" or "we") is for the report that comes with a change.
@MainActor
@Suite("Voice run report")
struct VoiceRunReportTests {
    private static let runs = ["before", "after", "before-shared", "after-shared"]

    private func row(_ label: String, _ summary: VoiceRunMetrics.Summary) -> String {
        let rate: (Int) -> String = { summary.written == 0 ? "–" : String(format: "%2d%%", Int((Double($0) / Double(summary.written) * 100).rounded())) }
        return "VOICE REPORT \(label.padding(toLength: 22, withPad: " ", startingAt: 0)) n=\(summary.written)/\(summary.scripts)"
            + " · avoided \(rate(summary.avoided)) · I/we \(rate(summary.pronoun)) · catchphrase-first \(rate(summary.catchphraseFirst))"
            + " · style-name \(rate(summary.styleName)) · emoji \(rate(summary.emoji)) · short \(rate(summary.tooShort))"
            + " · wrong-language \(rate(summary.wrongLanguage)) · words \(Int(summary.averageWords.rounded()))"
            + " · topic \(rate(summary.topicHits)) · sentences \(String(format: "%.0f%%", summary.sentenceRate * 100))"
            + " · opening \(String(format: "%.0f%%", summary.openingRate * 100))"
    }

    @Test func printsEveryRunKept() {
        var lines: [String] = []
        for run in Self.runs {
            guard let samples = try? VoiceRunFixture.samples(run) else { continue }
            let metrics = VoiceRunMetrics(samples)
            for condition in ["no-voice", "voice"] {
                guard let summary = metrics.byCondition[condition] else { continue }
                lines.append(row("\(run) · \(condition)", summary))
                // Only the same idea can be compared between creators: the shared ideas.
                guard run.hasSuffix("shared") else { continue }
                let distinction = String(format: "%.2f", VoiceRunMetrics.distinction(samples, condition: condition))
                lines.append("VOICE REPORT \(run) · \(condition) distinction \(distinction)")
            }
        }
        let report = lines.joined(separator: "\n")
        print(report)
        Attachment.record(report, named: "voice-report.txt")
        // The simulator sees the Mac's disk: the report is also left where it can be read without opening the result.
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/reports")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? report.write(to: folder.appendingPathComponent("voice-report.txt"), atomically: true, encoding: .utf8)
        #expect(!lines.isEmpty, "at least the baseline is kept")
    }
}
