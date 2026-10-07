//
//  PlatformGuide.swift
//  Cue Studio
//

import Foundation

/// What the AI is told about where the video will be posted (plan: platform, format, voice and topics all feed one prompt): the hook, the pace and
/// the ending that work there. In English whatever the interface language is, short, and in the positive. The length comes from the platform's rules
/// and the creator's choice (`ScriptRequestFactory`), not from here.
nonisolated enum PlatformGuide {
    static func line(for platform: Platform) -> String {
        switch platform {
        case .tiktok:
            "Platform: TikTok, vertical and fast. Hook in the first 3 seconds, one idea only, short punchy lines spoken like a friend; end with one easy action (comment, follow or save)."
        case .reels:
            "Platform: Instagram Reels. Personal but polished: a strong first line, one idea, a clear payoff, and an ending that asks to save or share."
        case .shorts:
            "Platform: YouTube Shorts. Under a minute: a curiosity hook, the payoff before the end, and a last line that loops back to the first."
        case .youtube:
            "Platform: YouTube long-form. Promise what the viewer will get, move through clear sections that each answer one question, re-hook before the middle, and close by pointing to the next video."
        case .linkedin:
            "Platform: LinkedIn. A professional first-person insight: open with a concrete observation or result, no slang, no emojis, no swearing, and end with a question that invites discussion."
        case .stories:
            "Platform: Instagram Stories. Casual and immediate, like talking to one friend: one point, very short, ending with a request for a reply or a vote."
        }
    }
}
