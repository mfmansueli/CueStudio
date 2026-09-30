//
//  TranslationRequest.swift
//  Cue Studio
//

import Foundation

/// Captions to translate: handed to the system's translation task by the view, which gives back a
/// session (downloading the languages first when needed, after asking).
struct TranslationRequest: Equatable, Identifiable {
    let id = UUID()
    let source: Locale.Language
    let target: CueLanguage
    /// Lines the creator corrected are translated again too.
    let replacingRevised: Bool
}
