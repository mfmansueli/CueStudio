//
//  UltraLabEffort.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// How hard Claude thinks in Ultra AI's lab (`AnthropicUltraClient`, `output_config.effort`): the other way, beside a smaller model
/// (`UltraLabProvider`), to make a script cheaper. Thinking is most of what a script costs. Picked in the lab, kept in the standard defaults,
/// read on every call. Gemini ignores it (its thinking is `UltraThinking`).
nonisolated enum UltraLabEffort: String, CaseIterable, Identifiable, Sendable {
    case high
    case medium
    case low

    static let key = "ultraLab.claudeEffort"

    static var selected: UltraLabEffort {
        UserDefaults.standard.string(forKey: key).flatMap(UltraLabEffort.init(rawValue:)) ?? .high
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
}
#endif
