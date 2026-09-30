//
//  CaptionTranslation.swift
//  Cue Studio
//

import Foundation

/// The captions in one other language, kept apart from the original lines.
nonisolated struct CaptionTranslation: Codable, Hashable, Identifiable, Sendable {
    var language: CueLanguage
    var lines: [TranslatedCaptionLine]

    var id: CueLanguage { language }

    /// Lines whose original changed (or went) since they were translated.
    func outdatedLines(against captions: [CaptionCue]) -> [TranslatedCaptionLine] {
        let byID = Dictionary(captions.map { ($0.id, $0) }) { first, _ in first }
        return lines.filter { line in
            let originals = line.cueIDs.compactMap { byID[$0] }
            return originals.count != line.cueIDs.count || CaptionText.joined(originals.map(\.text)) != line.sourceText
        }
    }
}
