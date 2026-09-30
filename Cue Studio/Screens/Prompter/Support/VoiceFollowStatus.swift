//
//  VoiceFollowStatus.swift
//  Cue Studio
//

import Foundation

/// What Voice Following is doing, told the same way in Selfie and Studio. Following the words is
/// only ever claimed while speech recognition really follows them; getting ready, downloading and
/// the fallback all scroll at the set speed while the creator talks, and say so.
enum VoiceFollowStatus: Equatable {
    /// Recognition follows the reading word by word.
    case followingWords
    /// The language's speech model is loading.
    case preparing
    /// The language's speech model is downloading; `progress` 0...1 when known.
    case downloading(CueLanguage?, progress: Double?)
    /// No word-by-word following here (see `SpeechUnavailableReason`): the text scrolls at the set
    /// speed while the creator talks.
    case scrollsWhileTalking

    init(followsSpeech: Bool, preparation: SpeechPreparation?) {
        switch (followsSpeech, preparation) {
        case (true, _): self = .followingWords
        case (false, .preparing?): self = .preparing
        case (false, .downloading(let language, let progress)?): self = .downloading(language, progress: progress)
        case (false, nil): self = .scrollsWhileTalking
        }
    }

    var followsWords: Bool { self == .followingWords }

    /// The tag before the status in the Selfie pill: "AUTO" when the voice sets the pace, the
    /// speed ("0.7×") when the text moves at it.
    func tag(speedLabel: String) -> String {
        followsWords ? String(localized: "AUTO") : speedLabel
    }

    /// The short status next to the waveform in Selfie.
    func shortLabel(isListening: Bool) -> String {
        switch self {
        case .followingWords where isListening: String(localized: "Listening")
        case .scrollsWhileTalking where isListening: String(localized: "While you talk")
        case .followingWords, .scrollsWhileTalking: String(localized: "Paused")
        case .preparing: String(localized: "Getting ready")
        case .downloading(_, let progress?): String(localized: "Downloading \(Self.percent(progress))")
        case .downloading(_, nil): String(localized: "Downloading")
        }
    }

    /// Studio's line under the controls, once the text plays.
    func detail(speedLabel: String) -> String {
        switch self {
        case .followingWords:
            String(localized: "Follows your words")
        case .scrollsWhileTalking:
            String(localized: "Scrolls at \(speedLabel) while you talk")
        case .preparing:
            String(localized: "Getting ready to follow your words. Scrolls at \(speedLabel) while you talk.")
        case .downloading(let language?, let progress?):
            String(localized: "Downloading \(language.localizedName) · \(Self.percent(progress)). Scrolls at \(speedLabel) while you talk.")
        case .downloading(_, let progress):
            String(localized: "Downloading this language · \(Self.percent(progress ?? 0)). Scrolls at \(speedLabel) while you talk.")
        }
    }

    /// What VoiceOver reads for the indicator.
    func accessibilityValue(isListening: Bool, speedLabel: String) -> String {
        switch self {
        case .followingWords: shortLabel(isListening: isListening)
        case .scrollsWhileTalking where !isListening: String(localized: "Paused")
        case .scrollsWhileTalking, .preparing, .downloading: detail(speedLabel: speedLabel)
        }
    }

    private static func percent(_ fraction: Double) -> String {
        min(1, max(0, fraction)).formatted(.percent.precision(.fractionLength(0)).locale(.interface))
    }
}
