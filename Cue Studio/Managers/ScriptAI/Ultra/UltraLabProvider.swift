//
//  UltraLabProvider.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Who writes Ultra AI's scripts in this Debug build (owner, 02/11/2026: try Claude in the app in place of Google): Google's Gemini through the
/// lab's Firebase app (`FirebaseUltraClient`), or Claude through the key copied to this iPhone (`AnthropicUltraClient`). Picked in Settings ›
/// Privacy & AI data › Ultra AI · Lab, kept in the standard defaults, read on every call (`UltraLabClient`), so a change needs no relaunch.
/// Claude comes in three sizes, to weigh what a cheaper model writes against what it saves (owner, 02/11/2026), and with an effort level
/// (`UltraLabEffort`).
nonisolated enum UltraLabProvider: String, CaseIterable, Identifiable, Sendable {
    case google
    case claudeOpus
    case claudeSonnet
    case claudeHaiku

    static let key = "ultraLab.provider"

    static var selected: UltraLabProvider {
        UserDefaults.standard.string(forKey: key).flatMap(UltraLabProvider.init(rawValue:)) ?? .google
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .google: "Gemini 3.5 Flash"
        case .claudeOpus: "Claude Opus 5.5"
        case .claudeSonnet: "Claude Sonnet 5.5"
        case .claudeHaiku: "Claude Haiku 5.5"
        }
    }

    /// The Claude API's model id; nil for Google.
    var claudeModel: String? {
        switch self {
        case .google: nil
        case .claudeOpus: "claude-opus-5-5"
        case .claudeSonnet: "claude-sonnet-5-5"
        case .claudeHaiku: "claude-haiku-5-5"
        }
    }

    /// A policy refusal is re-run on Anthropic's recommended model (`fallbacks: "default"`); Haiku has no such fallback, and the API refuses
    /// the parameter for it.
    var refusalFallback: Bool { self == .claudeOpus || self == .claudeSonnet }

    /// Its price in US dollars per million tokens (Anthropic's pricing page, read 02/11/2026; Google's in `UltraPrice.google`). Haiku's is for
    /// prompts up to 100K tokens, which a script's always are.
    var price: UltraPrice {
        switch self {
        case .google: .google
        case .claudeOpus: UltraPrice(inputPerMillion: 4, cachedInputPerMillion: 0.20, outputPerMillion: 20)
        case .claudeSonnet: UltraPrice(inputPerMillion: 2, cachedInputPerMillion: 0.20, outputPerMillion: 10)
        case .claudeHaiku: UltraPrice(inputPerMillion: 0.10, cachedInputPerMillion: 0.01, outputPerMillion: 0.50)
        }
    }
}
#endif
