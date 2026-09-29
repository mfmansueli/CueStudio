//
//  TextUse.swift
//  Cue Studio
//

import Foundation

/// What a look is for: a short text read at a glance, or captions read line after line for the
/// whole video. The same preset is set differently for each (captions are smaller, calmer and
/// always legible over the face).
nonisolated enum TextUse: String, Codable, CaseIterable, Sendable {
    case title, caption
}
