//
//  UltraFitRequest.swift
//  Cue Studio
//

import Foundation

/// What Ultra's fit sends (one call, only while Ultra writes, for a script that came back past its platform's range): the polished script, its
/// platform, the words the platform's range asks for, and how the creator speaks (`VoiceBriefBuilder.ultraProjection`'s delivery, the same the
/// polish gets). Fit to time on the page is Apple Intelligence's (owner, 01/11/2026).
nonisolated struct UltraFitRequest: Hashable, Sendable {
    let script: String
    let platform: Platform
    let range: ClosedRange<TimeInterval>
    var voice: CreatorVoice?
    /// The script's language, for cleaning the answer.
    var language: Locale.Language?
    /// The brief of a sponsored ad being fitted: the cut keeps the disclosure, the brand's line, the link and the code (`brandKeepLines`).
    var brand: BrandBrief?
    /// What "What Cue sends" shows for the script's word count (its preview has a placeholder for a script); nil counts the script.
    var countShown: String?

    /// The words the range asks for, at the creator's natural pace in the script's language (`ReadTime.pace(for:)`).
    var words: ClosedRange<Int> {
        let pace = language.flatMap(CueLanguage.matching(language:))
        let low = ReadTime.words(for: range.lowerBound, language: pace)
        return low...max(low, ReadTime.words(for: range.upperBound, language: pace))
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
            // The cut keeps the voice's rules as the draft did (the owner's B9; §11, A2).
            let rules = VoiceBriefBuilder.restrictionLines(for: voice.restrictionsOnly, register: PlatformRegister(platform))
            sections.append("The creator's rules (they hold through the cut):\n\(rules.joined(separator: "\n"))")
        }
        if let brand { sections.append(ScriptPromptBuilder.brandKeepLines(brand).joined(separator: "\n")) }
        sections.append("Script to fit:\n\"\"\"\n\(script)\n\"\"\"")
        return sections
    }
}
