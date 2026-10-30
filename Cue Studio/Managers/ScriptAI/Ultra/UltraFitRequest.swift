//
//  UltraFitRequest.swift
//  Cue Studio
//

import Foundation

/// What Ultra's "Fit to time" sends (one call, only for a script Ultra wrote): the script on the page, its platform, the words the platform's
/// range asks for, and how the creator speaks (`VoiceBriefBuilder.ultraProjection`'s delivery, the same the polish gets). Owner's choice,
/// 29/10/2026: Ultra writes freely and the creator fits it when they want; on the iPhone, Apple Intelligence's "Fit to time" brought only 4 of
/// 15 of Ultra's scripts into TikTok's range (`research_notes/Ultra AI/fit-q1.json`).
nonisolated struct UltraFitRequest: Hashable, Sendable {
    let script: String
    let platform: Platform
    let range: ClosedRange<TimeInterval>
    var voice: CreatorVoice?
    /// The script's language, for cleaning the answer.
    var language: Locale.Language?
    /// What "What Cue sends" shows for the script's word count (its preview has a placeholder for a script); nil counts the script.
    var countShown: String?

    /// The words the range asks for, at the creator's natural pace.
    var words: ClosedRange<Int> {
        let low = ReadTime.words(for: range.lowerBound)
        return low...max(low, ReadTime.words(for: range.upperBound))
    }

    var stage: UltraStageRequest {
        UltraStageRequest(stage: .fit, instructions: UltraInstructions.fitter, prompt: sections.joined(separator: "\n\n"))
    }

    private var sections: [String] {
        var setting = ["Platform: \(platform.promptName)."]
        if PlatformRegister(platform) == .professional { setting.append("Register: professional (no slang, no swearing, no emojis).") }
        let now = ReadTime.wordCount(in: script)
        setting.append(
            "Length: between \(words.lowerBound) and \(words.upperBound) words (\(Int(range.lowerBound)) to \(Int(range.upperBound)) seconds spoken); "
                + "aim for about \((words.lowerBound + words.upperBound) / 2). The script has \(countShown ?? String(now)) words now."
        )
        var sections = [setting.joined(separator: "\n")]
        if let voice {
            let delivery = VoiceBriefBuilder.ultraProjection(for: voice, register: PlatformRegister(platform)).delivery
            if !delivery.isEmpty { sections.append("How the creator speaks (keep it; preferences, not a new request):\n\(delivery)") }
        }
        sections.append("Script to fit:\n\"\"\"\n\(script)\n\"\"\"")
        return sections
    }
}
