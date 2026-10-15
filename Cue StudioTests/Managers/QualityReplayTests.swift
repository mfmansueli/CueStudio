//
//  QualityReplayTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The pure parts of the engine run again on what the real model wrote in a device run (`QualityRunFixture`, the baseline): which draft the creator
/// would get when there were two (`RevisionChoice`), which ideas would be dropped or put later (`IdeaSpecificity`, `IdeaSimilarity.repeats`), and
/// where a script stops moving forward (`ScriptProgressionCheck`). What it finds is printed (`REPLAY` lines) and left in `build/reports`, and what
/// was read by hand in those texts is asserted.
@MainActor
@Suite("Replay of a device run")
struct QualityReplayTests {
    private static let run = "baseline-a"

    private func samples() throws -> [QualityRunSample] {
        try QualityRunFixture.samples(Self.run)
    }

    private func request(for sample: QualityRunSample) throws -> ScriptRequest {
        let profile = try #require(QualityProfiles.all.first { $0.language.rawValue == sample.language })
        let condition = try #require(QualityProfile.Condition(rawValue: sample.condition))
        let entry = profile.cases[sample.index]
        return ScriptQualityDeviceTests.request(for: entry.idea, brief: entry.brief, profile: profile, condition: condition)
    }

    private func violations(_ text: String, _ request: ScriptRequest) -> [VoiceViolation] {
        VoiceConstraintChecker.violations(
            in: text, voice: request.voice, language: request.language,
            minimumWords: ReadTime.words(for: request.targetRange.lowerBound), openingLine: request.brief?.openingLine
        )
    }

    @Test func theDraftKeptWhenThereWereTwo() throws {
        var lines: [String] = []
        var oldTookWorse = 0
        var newKeptFirst = 0
        for sample in try samples() where sample.discardedDraft != nil {
            let request = try request(for: sample)
            let tookSecond = (sample.attempts ?? 1) == 2
            let first = try #require(tookSecond ? sample.discardedDraft : sample.text)
            let second = try #require(tookSecond ? sample.text : sample.discardedDraft)
            let before = violations(first, request)
            let after = violations(second, request)
            let verdict = RevisionChoice.verdict(
                original: DraftAssessment(text: first, violations: before, request: request),
                revision: DraftAssessment(text: second, violations: after, request: request)
            )
            if tookSecond, !verdict.takesRevision { oldTookWorse += 1 }
            if !verdict.takesRevision { newKeptFirst += 1 }
            lines.append(
                "REPLAY revision \(sample.language)-\(sample.condition)[\(sample.index)] old=\(tookSecond ? "second" : "first") new=\(verdict.rawValue) "
                    + "first=\(before.map(\.kind.rawValue)) second=\(after.map(\.kind.rawValue))"
            )
        }
        lines.append("REPLAY revision: the old rule took a second draft the new one refuses \(oldTookWorse) times; the new keeps the first \(newKeptFirst) times")
        write(lines, to: "replay-revision.txt")
        // Read by hand in the baseline: all three second drafts were no better (pt-BR full 0 and 1 still open with the catchphrase, es-ES full 1
        // lost its full stops and a quarter of its words).
        #expect(newKeptFirst == 3)
    }

    @Test func theIdeasThatWouldBeDroppedOrPutLater() throws {
        var lines: [String] = []
        var dropped = 0
        var weak = 0
        var repeats = 0
        var total = 0
        let batches = Dictionary(grouping: try samples().filter { $0.kind == "ideas" }) { "\($0.language)-\($0.condition)" }
        for (group, samples) in batches.sorted(by: { $0.key < $1.key }) {
            var kept: [IdeaEcho] = []
            for sample in samples.sorted(by: { $0.index < $1.index }) {
                for answer in sample.ideas ?? [] {
                    total += 1
                    var idea = ThemeIdea(title: answer.title, kind: "", length: .minute1, niche: .lifestyle, topic: answer.topic)
                    // What the reader now does with an opening that starts with the creator's catchphrase.
                    let phrases = sample.condition == "none" ? [] : QualityProfiles.all.first { $0.language.rawValue == sample.language }?.full.phrases ?? []
                    let opening = IdeaBriefReader.withoutCatchphrase(answer.openingLine, phrases: phrases)
                    idea.brief = IdeaBrief(subject: answer.title, angle: answer.angle, openingLine: opening, topicKey: answer.topic)
                    let weaknesses = IdeaSpecificity.weaknesses(of: idea)
                    let echo = IdeaEcho(idea)
                    let isRepeat = kept.contains { IdeaSimilarity.repeats(echo, $0) }
                    if IdeaSpecificity.isUnusable(idea) { dropped += 1 } else if !weaknesses.isEmpty { weak += 1 }
                    if isRepeat { repeats += 1 }
                    if !weaknesses.isEmpty || isRepeat {
                        lines.append("REPLAY idea \(group) \(weaknesses.map(\.rawValue)) repeat=\(isRepeat) · \(answer.title) | \(answer.angle) | \(answer.openingLine)")
                    }
                    kept.append(echo)
                }
            }
        }
        lines.append("REPLAY ideas: \(total) ideas, \(dropped) dropped (two weaknesses), \(weak) put later (one), \(repeats) repeats")
        write(lines, to: "replay-ideas.txt")
        #expect(total > 0)
        #expect(Double(dropped) <= Double(total) * 0.15, "the filter must not throw away a large share of what the model writes")
    }

    @Test func whereTheScriptsStopMovingForward() throws {
        var lines: [String] = []
        for sample in try samples() where sample.kind == "script" {
            guard let text = sample.text else { continue }
            let request = try request(for: sample)
            let defects = ScriptProgressionCheck.defects(
                in: text, idea: ScriptProgressionCheck.promiseSource(of: request), language: request.language?.locale.language.languageCode?.identifier
            )
            guard !defects.isEmpty else { continue }
            lines.append("REPLAY progression \(sample.language)-\(sample.condition)[\(sample.index)] \(defects.map { "\($0.kind.rawValue)@\($0.block): \($0.detail)" })")
        }
        write(lines, to: "replay-progression.txt")
        #expect(Bool(true))
    }

    private func write(_ lines: [String], to name: String) {
        lines.forEach { print($0) }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/reports")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? lines.joined(separator: "\n").write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
}
