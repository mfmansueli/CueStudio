//
//  PermissionNotice.swift
//  Cue Studio
//

import Foundation

/// A permission the creator turned off, as the one notice form says it (04 · Componentes §3): the same words wherever it is met, "The
/// microphone" (never "Mic"), and the way out is always Settings (`PermissionNoticeCard`).
nonisolated enum PermissionNotice: Hashable, Sendable {
    case photos
    case microphone

    var title: String {
        switch self {
        case .photos: String(localized: "Photos is off for Cue")
        case .microphone: String(localized: "The microphone is off for Cue")
        }
    }

    var line: String {
        switch self {
        case .photos: String(localized: "Allow it to save your video.")
        case .microphone: String(localized: "Allow it to record your voice.")
        }
    }
}
