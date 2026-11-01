//
//  IdeaLibraryBuildTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The developer tool that turns what Ultra AI wrote (`IdeaLibraryDeviceTests`, gathered by `tools/ideas/collect_library.py` into
/// `research_notes/Ideas/library-raw/<localization>.jsonl`) into the packs the app holds (`Cue Studio/SupportFiles/IdeaLibrary/`), with the app's
/// own filters: the language the pack is for (`OutputLanguageCheck`), no idea with both weaknesses (`IdeaSpecificity`), no title said again in
/// other words (`IdeaSimilarity`), each topic's ideas with their angles in turn. Prints what each filter took out.
///
/// The simulator can't open the Desktop, so the files go through a folder outside it: `python3 tools/ideas/collect_library.py stage <folder>`,
/// `TEST_RUNNER_CUE_IDEA_LIBRARY_DIR=<folder> scripts/test.sh only "Cue StudioTests/IdeaLibraryBuildTests"`, then
/// `python3 tools/ideas/collect_library.py install <folder>`.
@Suite("Idea library packs, built", .enabled(if: ProcessInfo.processInfo.environment["CUE_IDEA_LIBRARY_DIR"] != nil))
struct IdeaLibraryBuildTests {
    private struct Raw: Decodable {
        let topic: String
        let angle: String
        let title: String
        let pointOfView: String
        let openingLine: String
    }

    /// The folder the raw ideas are staged in (`raw/`) and the packs are written to (`packs/`).
    private static let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CUE_IDEA_LIBRARY_DIR"] ?? NSTemporaryDirectory())

    /// The longest title a library idea may have (the card's headline).
    static let titleLimit = 90

    @Test func buildThePacks() throws {
        let raw = Self.folder.appending(path: "raw")
        let output = Self.folder.appending(path: "packs")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let files = try FileManager.default.contentsOfDirectory(at: raw, includingPropertiesForKeys: nil).filter { $0.pathExtension == "jsonl" }
        try #require(!files.isEmpty, "Nothing gathered in \(raw.path)")
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let localization = file.deletingPathExtension().lastPathComponent
            let rows = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").compactMap { line in
                try? JSONDecoder().decode(Raw.self, from: Data(line.utf8))
            }
            let (pack, report) = Self.pack(rows, localization: localization)
            try Self.encoded(pack).write(to: output.appending(path: IdeaLibrary.resourceName(for: localization) + ".json"), atomically: true, encoding: .utf8)
            print("IDEALIBRARY \(localization): \(rows.count) written, \(pack.ideas.count) kept · \(report)")
        }
    }

    private static func pack(_ rows: [Raw], localization: String) -> (IdeaLibraryPack, String) {
        let language = Locale.Language(identifier: localization)
        var dropped: [String: Int] = [:]
        var kept: [IdeaLibraryPack.Idea] = []
        for niche in Niche.offered {
            var topic: [IdeaLibraryPack.Idea] = []
            for row in rows where row.topic == niche.rawValue {
                let idea = IdeaLibraryPack.Idea(
                    topic: row.topic, angle: row.angle, title: trimmed(row.title), pointOfView: trimmed(row.pointOfView),
                    openingLine: unquoted(trimmed(row.openingLine))
                )
                if let reason = reason(toDrop: idea, language: language, among: topic) {
                    dropped[reason, default: 0] += 1
                } else {
                    topic.append(idea)
                }
            }
            kept += inTurn(topic)
        }
        let report = dropped.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        return (IdeaLibraryPack(language: localization, ideas: kept), report.isEmpty ? "nothing dropped" : "dropped: " + report)
    }

    private static func reason(toDrop idea: IdeaLibraryPack.Idea, language: Locale.Language, among kept: [IdeaLibraryPack.Idea]) -> String? {
        guard let angle = IdeaAngle(rawValue: idea.angle) else { return "unknown angle" }
        guard !idea.title.isEmpty, !idea.pointOfView.isEmpty, !idea.openingLine.isEmpty else { return "empty part" }
        guard idea.title.count <= titleLimit else { return "long title" }
        guard OutputLanguageCheck.isPlausible([idea.title, idea.pointOfView, idea.openingLine].joined(separator: " "), in: language) else {
            return "other language"
        }
        var theme = ThemeIdea(title: idea.title, kind: angle.kind, length: .minute1, niche: .lifestyle)
        theme.brief = IdeaBrief(subject: idea.title, angle: idea.pointOfView, openingLine: idea.openingLine, angleKind: angle.rawValue)
        guard !IdeaSpecificity.isUnusable(theme) else { return "weak" }
        let words = IdeaSimilarity.words(in: idea.title)
        let repeats = kept.contains { other in
            other.title.localizedCaseInsensitiveCompare(idea.title) == .orderedSame || IdeaSimilarity.areAlike(words, IdeaSimilarity.words(in: other.title))
        }
        return repeats ? "repeated" : nil
    }

    /// A topic's ideas with the angles in turn (the first of each angle, then the second…), so the card doesn't show three myths in a row.
    private static func inTurn(_ ideas: [IdeaLibraryPack.Idea]) -> [IdeaLibraryPack.Idea] {
        let byAngle = IdeaAngle.allCases.map { angle in ideas.filter { $0.angle == angle.rawValue } }
        let longest = byAngle.map(\.count).max() ?? 0
        return (0..<longest).flatMap { index in byAngle.compactMap { index < $0.count ? $0[index] : nil } }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unquoted(_ line: String) -> String {
        let quotes = CharacterSet(charactersIn: "\"“”«»„‘’'「」『』")
        let inner = line.trimmingCharacters(in: quotes.union(.whitespaces))
        return inner.isEmpty ? line : inner
    }

    /// One idea a line, so a change to the library reads as the ideas it touched.
    private static func encoded(_ pack: IdeaLibraryPack) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let ideas = try pack.ideas.map { String(bytes: try encoder.encode($0), encoding: .utf8) ?? "" }
        let language = String(bytes: try encoder.encode(pack.language), encoding: .utf8) ?? "\"\(pack.language)\""
        return "{\"version\":\(pack.version),\"language\":\(language),\"ideas\":[\n" + ideas.joined(separator: ",\n") + "\n]}\n"
    }
}
