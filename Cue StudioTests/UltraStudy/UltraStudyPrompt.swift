//
//  UltraStudyPrompt.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Applies a job's variants (`UltraStudyVariant`) to each stage the app builds (`UltraPayload`), by replacing or following the app's exact
/// words. A variant whose words a stage must have but doesn't throws, so a variant is never measured unapplied.
nonisolated struct UltraStudyPrompt: Sendable {
    let variants: [UltraStudyVariant]
    let format: FormatChoice
    /// The idea's kind, for `angleKind` (nil when the idea was typed).
    let angle: IdeaAngle?

    struct Missing: Error, CustomStringConvertible {
        let variant: UltraStudyVariant
        let stage: UltraStageRequest.Stage
        var description: String { "\(variant.rawValue) found nothing to change in the \(stage.rawValue) stage" }
    }

    /// The app's title rule in the editor's instructions (`UltraInstructions.editor`).
    static let titleRule = "\"title\", a short title for the script in its language (at most eight words, no quotes or emoji)"
    static let keptTitleRule = "\"title\", the idea's title exactly as given after “Subject:” in the context, unchanged"
    static let subtitleRule = "\"title\", a subtitle of at most eight words, in the script's language, that names this script's own take on the "
        + "idea's title given after “Subject:” (the app shows it under that title, so do not repeat the title's words; no quotes or emoji)"
    /// The line the kept title adds after the subject: the script delivers what the title promises.
    static let keptTitleLine = "This subject stays the video's title: the script must deliver what it promises."

    func applied(to request: UltraStageRequest) throws -> UltraStageRequest {
        var prompt = request.prompt
        var instructions = request.instructions
        for variant in variants {
            switch variant {
            case .formatFull:
                guard let line = UltraStudyFormats.line(for: format) else { continue }
                prompt = try replacingFormatLine(in: prompt, with: line, stage: request.stage)
            case .autoFull:
                guard format == .auto else { continue }
                prompt = try replacingAutoLine(in: prompt, with: UltraStudyAutoGenres.line(for: angle), stage: request.stage)
            case .angleKind:
                guard let angle else { continue }
                prompt = try following(subjectIn: prompt, with: Self.kindLine(angle), stage: request.stage, variant: variant)
            case .titleKeep:
                prompt = try following(subjectIn: prompt, with: Self.keptTitleLine, stage: request.stage, variant: variant)
                if request.stage == .review { instructions = try replacing(Self.titleRule, with: Self.keptTitleRule, in: instructions, variant) }
            case .titleSubtitle:
                if request.stage == .review { instructions = try replacing(Self.titleRule, with: Self.subtitleRule, in: instructions, variant) }
            }
        }
        return UltraStageRequest(stage: request.stage, instructions: instructions, prompt: prompt, thinking: request.thinking)
    }

    static func kindLine(_ angle: IdeaAngle) -> String {
        "Kind of idea: \(angle.ask). Keep that genre: a story is told as a story, an opinion is argued, and a list is written only "
            + "when the idea is a list."
    }

    // MARK: - Steps

    /// The app's format line ("Format chosen by the creator: …") swapped for `line`, in every stage but a fit (which carries no setting).
    private func replacingFormatLine(in prompt: String, with line: String, stage: UltraStageRequest.Stage) throws -> String {
        var lines = prompt.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.hasPrefix("Format chosen by the creator:") }) else {
            if stage == .fit { return prompt }
            throw Missing(variant: .formatFull, stage: stage)
        }
        lines[index] = line
        return lines.joined(separator: "\n")
    }

    /// The app's Auto line ("Format: not chosen. Read the genre…") swapped for `line`, in every stage but a fit.
    private func replacingAutoLine(in prompt: String, with line: String, stage: UltraStageRequest.Stage) throws -> String {
        var lines = prompt.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.hasPrefix("Format: not chosen. Read the genre") }) else {
            if stage == .fit { return prompt }
            throw Missing(variant: .autoFull, stage: stage)
        }
        lines[index] = line
        return lines.joined(separator: "\n")
    }

    /// `line` right after the inspiration's "Subject: …" line, in every stage that carries the inspiration.
    private func following(
        subjectIn prompt: String, with line: String, stage: UltraStageRequest.Stage, variant: UltraStudyVariant
    ) throws -> String {
        var lines = prompt.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.hasPrefix("Subject: ") }) else {
            if stage == .fit { return prompt }
            throw Missing(variant: variant, stage: stage)
        }
        lines.insert(line, at: index + 1)
        return lines.joined(separator: "\n")
    }

    private func replacing(_ old: String, with new: String, in text: String, _ variant: UltraStudyVariant) throws -> String {
        guard text.contains(old) else { throw Missing(variant: variant, stage: .review) }
        return text.replacingOccurrences(of: old, with: new)
    }
}
