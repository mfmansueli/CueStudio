//
//  PracticeVoice.swift
//  Cue Studio
//

import Foundation

/// What moves the practice's text (1.6), as the creator is told under the box and on the card: their words (Voice Following), getting
/// ready to follow them, their voice's level when this iPhone can't follow the words, or a steady pace without the microphone. In every
/// case the text stands still until they start (`PrompterViewModel.advance`), except Steady, which can't hear them.
nonisolated enum PracticeVoice: Equatable, Sendable {
    /// Recognition is loading its model for the script's language.
    case preparing
    /// Recognition is downloading its model; 0...1 once the system says.
    case downloading(progress: Double?)
    /// Recognition follows the reading word by word.
    case following
    /// The words can't be followed here (`SpeechUnavailableReason`): the text moves while the creator talks.
    case scrollsWhileTalking
    /// No microphone: the text scrolls at the set speed after the count-in.
    case steady

    /// The script may say the teleprompter follows the voice: it does, or is getting ready to.
    var followsWords: Bool {
        switch self {
        case .preparing, .downloading, .following: true
        case .scrollsWhileTalking, .steady: false
        }
    }

    /// The line under the box. `isReading`: the text has started; `isListening`: the creator's voice is heard now.
    func status(isReading: Bool, isListening: Bool) -> String {
        switch self {
        case .preparing:
            String(localized: "Getting ready to follow your voice")
        case .downloading(let progress?):
            String(localized: "Getting Voice Following ready · \(min(1, max(0, progress)).formatted(.percent.precision(.fractionLength(0)).locale(.interface)))")
        case .downloading(nil):
            String(localized: "Getting Voice Following ready")
        case .following where !isReading:
            String(localized: "Voice Following is on")
        case .following where isListening:
            String(localized: "Following your voice")
        case .following:
            String(localized: "Waiting for your voice")
        case .scrollsWhileTalking where isReading && !isListening:
            String(localized: "Waiting for your voice")
        case .scrollsWhileTalking:
            String(localized: "Moves while you talk")
        case .steady:
            String(localized: "Microphone off · Steady scroll")
        }
    }

    /// The SF Symbol before the status.
    var symbolName: String {
        switch self {
        case .preparing, .downloading: "hourglass"
        case .following, .scrollsWhileTalking: "waveform"
        case .steady: "mic.slash"
        }
    }

    /// What the card tells the creator to do, and what the text will do then.
    var instruction: String {
        switch self {
        case .preparing, .downloading, .following:
            String(localized: "Tap play and wait for the count. Then read out loud: the text follows your voice.")
        case .scrollsWhileTalking: String(localized: "Tap play and wait for the count. Then read out loud: the text moves while you talk.")
        case .steady: String(localized: "Tap play and wait for the count. Then read: the text scrolls at a steady pace.")
        }
    }
}
