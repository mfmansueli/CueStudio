//
//  PCCScriptDirection.swift
//  Cue Studio
//

import Foundation

/// Editorial direction for PCC's larger request budget. Kept out of the measured local prompt;
/// it uses the same generation call and never asks for a separate plan or a fabricated biography.
nonisolated enum PCCScriptDirection {
    static func usesAutomaticFormat(_ request: ScriptRequest) -> Bool {
        request.modelRoute == .privateCloud && request.isFreePrompt && request.format == nil && request.formatChoice != .talkingHead
    }

    /// The model reads intent in the creator's language during the same call that writes the script.
    /// An English keyword guess must not lock Auto into the creator's usual format before PCC reads it.
    static func automaticFormatLines(for request: ScriptRequest) -> [String] {
        guard usesAutomaticFormat(request) else { return [] }
        return [
            "Format is Automatic. Read the entire current request in its own language and choose the creative direction that best serves its intent. No format has been selected for you. Usual formats are a fallback only when the request gives no direction.",
            "Choose a tutorial for teaching a process, a list for distinct tips or reasons, a story for a supplied experience, a review or comparison for evaluating options, an opinion or reply for a viewpoint or comment, an announcement for supplied news, myth vs fact for correcting a belief, POV for a requested scene, or a sincere statement for a serious situation. For a general explanation, build a clear explanatory arc. Combine compatible approaches only when the request needs it.",
            "A product mention alone does not mean sponsorship. Use a sponsored-ad direction only when the request explicitly describes paid promotion, and disclose that paid partnership within the script (#ad). Never invent a brand deal, personal test or experience. A serious statement takes priority over entertainment: no hype, jokes, promotional hook or engagement CTA.",
            "Return blocks in the order that fits the chosen direction, with short descriptive block labels. Do not force Hook / Body / CTA onto every idea, force a twist onto an explanation, or show a format-selection rationale. The chosen structure must serve the creator's request, not change its subject.",
            "If the request supplies too little detail, use a useful, modest interpretation of the stated subject without inventing the creator's biography. Keep the result within the requested length.",
        ]
    }

    /// Platform controls delivery, not the creator's intention or an automatic engagement ending.
    static func platformLine(for platform: Platform) -> String {
        let delivery: String = switch platform {
        case .tiktok: "vertical, immediate, conversational; get to the subject quickly"
        case .reels: "personal but polished; one clear through-line with a useful payoff"
        case .shorts: "compact and focused; deliver the promised answer within the chosen duration"
        case .youtube: "clear sections, with each section developing the subject rather than repeating the hook"
        case .linkedin: "professional and specific; no slang, emojis or swearing"
        case .stories: "casual and immediate, addressing one person with one focused point"
        }
        return "Platform: \(platform.promptName). Delivery: \(delivery). Platform conventions never require an engagement CTA, a personal anecdote or a sales pitch."
    }

    static func instructions(for request: ScriptRequest) -> [String] {
        guard request.modelRoute == .privateCloud else { return [] }
        var lines = [
            "The creator's current request determines this video's subject, intended takeaway and explicit requirements. Their usual topics, openings, endings and style are defaults, not reasons to change that request. Keep the selected language, format, length, brand restrictions and the creator's avoid rules.",
            "Use the supplied details accurately: keep names, quantities, qualifications and required phrases. Do not turn a possibility into a promise or an opinion into a verified fact. Missing information is unknown, not permission to invent a personal experience, testimonial, result, price or credential.",
            "Preserve who did what: a team action must not become a personal action, and someone else's experience must not become the creator's. Do not add a workplace, personal test, learned lesson, future posting plan or commitment unless it was supplied. Clearly hypothetical teaching examples are allowed; never present them as the creator's past.",
            "Use the voice profile to choose vocabulary, rhythm, perspective and the audience's level of explanation. Do not recite the profile, insert unrelated interests or repeat a catchphrase to prove you used it.",
        ]
        if request.structure.isSerious {
            lines.append("Make the statement clear about what happened, responsibility and any supplied next step. Preserve uncertainty. Never invent an incident, excuse, remedy or commitment to complete the structure.")
        } else {
            if usesAutomaticFormat(request) {
                lines.append("If the current request is a serious statement, disregard usual humorous tone, catchphrases, attention hooks and engagement endings; use a direct opening and sincere close instead.")
            }
            lines += [
                "For non-serious videos, build one coherent through-line: an opening with a specific reason to listen, development that delivers what the opening promises, and an ending earned by that development. Each block must add something new rather than rephrase the previous block.",
                "Replace abstract advice with an observable action and why it helps. For a tutorial, explain what to adjust, what to look or listen for, and what to change if it fails. For a comparison, use the same relevant criterion for both choices and explain the tradeoff. For an opinion, support the viewpoint with a reason rather than repeating it. Do not invent measurements or sources to sound specific.",
                "Make the takeaway useful to this audience with concrete explanation, a practical step or a clearly hypothetical example when appropriate. Prefer a fresh, relevant angle over generic motivation, exaggerated hooks or filler. Do not force a surprise twist or an example where the request does not call for one.",
                "When the request asks for a number of steps or points, give that many genuinely distinct actions or ideas. Do not split one action into near-duplicates to fill the count. Open on the subject itself rather than announcing that you are about to explain it.",
                "Honor an explicitly requested ending, including no call to action. Otherwise use the creator's ending preference only when it fits this video; avoid a generic follow, like or subscribe sign-off. An opening promise must be fulfilled before any invitation.",
            ]
        }
        if request.brand != nil {
            lines.append("Persuasion comes from the supplied product details and their relevance to the audience. Do not add a benefit, comparison or urgency that the brand brief does not support. Preserve the paid-partnership disclosure.")
        }
        lines.append("Remove sentences that merely announce helpfulness, calm explanation, community values or the intention to explain. Express the voice through wording and rhythm instead. If a sentence could be pasted unchanged into an unrelated video, replace it with relevant substance or remove it. Never pad a short brief with invented context just to fill duration.",
            "Before returning only the requested title and script blocks, check that the current request's requirements are covered, the opening's promise is delivered, the details remain faithful, and no block pads the length with repetition. Revise within this answer; do not output a plan, checklist or explanation.")
        return lines
    }

    /// Last in the user prompt: required wording must survive stronger style/profile preferences.
    static let finalCheck = "Final check against the current request: any text explicitly requested exactly or verbatim must appear in a spoken block character-for-character, including its capitalization and punctuation. Copy that text as a complete unchanged phrase; do not substitute synonyms, change its punctuation or only convey its meaning. Preserve the supplied facts and who did what. Do not add personal history or future commitments to fill the length."
}
