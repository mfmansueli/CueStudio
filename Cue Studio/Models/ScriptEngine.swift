//
//  ScriptEngine.swift
//  Cue Studio
//

import Foundation

/// Which AI writes a script. Apple Intelligence (this iPhone or Private Cloud Compute) is the default; Ultra is Google's Gemini through Firebase,
/// only with the creator's explicit permission (`UltraConsentService`), never as a silent substitute or fallback for Apple's.
nonisolated enum ScriptEngine: String, Codable, Hashable, Sendable {
    case apple
    case ultra

    /// The name the creator sees on the dock's chip and the page.
    var label: String {
        switch self {
        case .apple: String(localized: "Apple Intelligence")
        case .ultra: String(localized: "Ultra AI")
        }
    }
}
