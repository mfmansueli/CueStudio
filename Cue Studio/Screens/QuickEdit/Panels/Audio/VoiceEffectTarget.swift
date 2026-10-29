//
//  VoiceEffectTarget.swift
//  Cue Studio
//

import Foundation

/// What Voice effects changes: a clip's sound, or a voice-over (recorded or spoken from text).
enum VoiceEffectTarget: Hashable {
    case clip(UUID)
    case voiceOver(UUID)
}
