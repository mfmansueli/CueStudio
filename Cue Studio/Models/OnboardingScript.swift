//
//  OnboardingScript.swift
//  Cue Studio
//

import Foundation

/// The first flight's practice script (1.4 shows it, 1.6 reads it): the same few lines for everyone, whatever topics were picked, as a hook,
/// a body and a call to action. Read out loud, it says what Cue does. Its body claims the teleprompter follows the voice, which is only true
/// while word-by-word Voice Following works; when it can't (no microphone, a language this iPhone can't follow), the practice reads the
/// version without that claim.
nonisolated struct OnboardingScript: Hashable, Sendable {
    var title: String
    var hook: String
    var body: String
    var cta: String

    /// The whole script, one paragraph per part.
    var text: String { [hook, body, cta].filter { !$0.isEmpty }.joined(separator: "\n\n") }

    /// How long it takes to read out loud at a natural pace (`ReadTime`), in whole seconds.
    var readingSeconds: Int { max(1, Int(ReadTime.seconds(for: text).rounded())) }

    /// The practice script. `followsVoice`: the teleprompter follows the creator's words in this practice (the body says so); otherwise the
    /// body only says it reads on a teleprompter.
    static func practice(followsVoice: Bool = true) -> OnboardingScript {
        OnboardingScript(
            title: String(localized: "From idea to video"),
            hook: String(localized: "An idea is good. Seeing it become a video is even better."),
            body: followsVoice
                ? String(localized: "Cue Studio helps me write it, read it with a teleprompter that follows my voice, and record it right here. I can add automatic captions and edit my take before sharing it.")
                : String(localized: "Cue Studio helps me write it, read it on a teleprompter, and record it right here. I can add automatic captions and edit my take before sharing it."),
            cta: String(localized: "My idea gets to sound like me and reach the people I made it for.")
        )
    }
}
