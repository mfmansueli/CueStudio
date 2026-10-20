//
//  CaptionRecording.swift
//  Cue Studio
//

import Foundation

/// One recording captions listen to: the take (`source` nil) or another the montage plays, with its script's text (empty without
/// one), the language it's heard in, and the likely languages whose first seconds are compared first (none: heard in `language`).
struct CaptionRecording {
    let source: UUID?
    let url: URL
    let script: String
    let language: SpeechLanguageRequest
    let candidates: [CueLanguage]
}
