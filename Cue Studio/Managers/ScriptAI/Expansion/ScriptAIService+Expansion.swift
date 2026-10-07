//
//  ScriptAIService+Expansion.swift
//  Cue Studio
//

import Foundation
import FoundationModels

extension ScriptAIService {
    /// A script that came out shorter than asked, written longer one block at a time (`ScriptExpansion`), or one far over, shorter: each block is
    /// given to the model on its own with the number of words it has to reach. It never makes anything worse: a block that comes back no longer, in
    /// another language or with something the creator asked never to write is left as it was, and any failure leaves the script as it is.
    /// Whether a script far from its length is changed block by block (the device measurement compares it with leaving it be).
    nonisolated(unsafe) static var expandsShortScripts = true

    /// - Parameter meter: told how many of the blocks are back (the percentage on the star).
    func expandingIfShort(
        _ script: GeneratedScript, for request: ScriptRequest, on model: AIModelRoute, language: String?, meter: WritingProgressMeter? = nil
    ) async -> GeneratedScript {
        guard script.usedLanguageModel, Self.expandsShortScripts else { return script }
        let minimum = ReadTime.words(for: request.targetRange.lowerBound)
        let maximum = ReadTime.words(for: request.targetRange.upperBound)
        let steps = ScriptExpansion.steps(for: script.text, minimumWords: minimum, maximumWords: maximum)
        guard !steps.isEmpty else { return script }
        let blocks = ScriptExpansion.blocks(of: script.text)
        let guide = ScriptPromptBuilder.formatGuide(for: request)
        var replacements: [Int: String] = [:]
        meter?.record(.lengthening(done: 0, of: steps.count))
        for (done, step) in steps.enumerated() {
            if Task.isCancelled { return script }
            let purpose = guide.blocks.count == blocks.count ? guide.purposes[step.index] : nil
            let prompt = ScriptExpansionPrompt.prompt(for: step, of: blocks, request: request, purpose: purpose)
            let session = session(on: model, instructions: ScriptExpansionPrompt.instructions(for: request, direction: step.direction))
            let options = GenerationOptions(maximumResponseTokens: min(1_500, step.target * 3 + 120))
            let started = ContinuousClock.now
            do {
                let answer = try await answering { try await session.respond(to: prompt, options: options).content }
                let text = ScriptPromptBuilder.clean(answer)
                let words = ScriptExpansion.words(in: text)
                if step.isShorter ? (words < step.words && words > 0) : words > step.words { replacements[step.index] = text }
            } catch is CancellationError {
                return script
            } catch {
                AIFailureReport.note(
                    error, operation: "script.expand", route: model, language: language, seconds: started.duration(to: .now).inSeconds, isFinal: false
                )
            }
            meter?.record(.lengthening(done: done + 1, of: steps.count))
        }
        guard !replacements.isEmpty else { return script }
        let text = ScriptExpansion.assembling(blocks, replacing: replacements)
        // Only a script that is still in its language, and breaks no more of what the creator asked than before, takes the place of the first.
        guard (try? Self.requireLanguage(request.language?.locale.language, in: text)) != nil else { return script }
        let kinds = VoiceConstraintChecker.violations(in: text, voice: request.voice, language: request.language, minimumWords: minimum).map(\.kind)
        guard kinds.filter({ $0 != .tooShort }).count <= script.voiceViolations.filter({ $0 != .tooShort }).count else { return script }
        var longer = script
        longer.text = text
        longer.expandedBlocks = replacements.count
        longer.voiceViolations = kinds
        return longer
    }
}
