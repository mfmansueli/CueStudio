//
//  ScriptIdea.swift
//  Cue Studio
//

import Foundation

/// The kind of video a creator says they want to make, picked on the empty Scripts screen before
/// writing the idea. It goes to the model with the text (one line of guidance in the prompt) and
/// never writes anything by itself.
nonisolated enum ScriptIdea: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case tip, product, story

    var id: String { rawValue }

    /// The chip.
    var label: String {
        switch self {
        case .tip: String(localized: "Share a tip")
        case .product: String(localized: "Show a product")
        case .story: String(localized: "Tell a story")
        }
    }

    /// What the card asks while the chip is picked.
    var question: String {
        switch self {
        case .tip: String(localized: "What do you want to teach?")
        case .product: String(localized: "Which product, and what do you like about it?")
        case .story: String(localized: "What happened?")
        }
    }

    /// The line the model is given with the creator's text (always in English, like the rest of the prompt).
    var instruction: String {
        switch self {
        case .tip: "The video gives the audience one useful tip they can use right away: lead with it and keep it practical."
        case .product: "The video shows a product and what the creator likes about it: be concrete and honest, with no inflated claims."
        case .story: "The video tells a story of something that happened: give it a beginning, a turn and a point."
        }
    }
}

/// What the empty Scripts screen hands to the generation flow: the creator's text and the kind of
/// video picked with it, if any.
nonisolated struct ScriptIdeaSeed: Hashable, Sendable {
    var text: String
    var idea: ScriptIdea?
}
