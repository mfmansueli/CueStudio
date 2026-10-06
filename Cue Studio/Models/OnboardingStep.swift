//
//  OnboardingStep.swift
//  Cue Studio
//

import Foundation

/// The first flight ("primeiro voo"): a welcome and five short chapters that already use the app for real.
/// The first star plays later, after the first real take.
nonisolated enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    /// Chapter 1: pick the topics; each becomes a world.
    case universe
    /// Chapter 2: pick the first platform (a galaxy).
    case voyage
    /// Chapter 3: the first script, written in the topic.
    case script
    /// Chapter 4: microphone and camera, in the story.
    case voice
    /// Chapter 5: a practice run of the teleprompter.
    case practice

    /// The bar's segment this step lights (0...3); the welcome has none. The practice shares the fourth with the permissions (the boards' 1.5 and
    /// 1.6 both light it); the fifth is the first star's.
    var segment: Int? {
        self == .welcome ? nil : min(rawValue - 1, 3)
    }

    static let segmentCount = 5

    /// "CHAPTER 2 · YOUR FIRST VOYAGE".
    var chapterLabel: String {
        switch self {
        case .welcome: String(localized: "CUE STUDIO")
        case .universe: String(localized: "CHAPTER 1 · YOUR UNIVERSE")
        case .voyage: String(localized: "CHAPTER 2 · YOUR FIRST VOYAGE")
        case .script: String(localized: "CHAPTER 3 · YOUR FIRST MESSAGE")
        case .voice: String(localized: "CHAPTER 4 · GIVE IT A VOICE")
        case .practice: String(localized: "CHAPTER 5 · PRACTICE")
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
