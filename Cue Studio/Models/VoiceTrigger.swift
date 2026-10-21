//
//  VoiceTrigger.swift
//  Cue Studio
//

import Foundation

/// A moment that asks a question sooner, once (08 §3).
nonisolated enum VoiceTrigger: String, Codable, CaseIterable, Sendable {
    case firstExport, secondGeneratedEdit, thirdScriptRecorded

    var question: VoiceQuestion {
        switch self {
        case .firstExport: .platforms
        case .secondGeneratedEdit: .words
        case .thirdScriptRecorded: .example
        }
    }
}
