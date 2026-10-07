//
//  ScriptType+Prompt.swift
//  Cue Studio
//

import Foundation

nonisolated extension ScriptType {
    /// What the AI reads for a format the creator films most (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .ad: "sponsored ads"
        case .review: "reviews"
        case .tutorial: "tutorials"
        case .list: "lists and tips"
        case .story: "storytimes"
        case .opinion: "hot takes and replies"
        case .launch: "launches"
        case .apology: "apologies"
        case .mythFact: "myth vs fact"
        case .pov: "POV videos"
        }
    }
}
