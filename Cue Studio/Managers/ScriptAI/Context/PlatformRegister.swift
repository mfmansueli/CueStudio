//
//  PlatformRegister.swift
//  Cue Studio
//

import Foundation

/// How formal a platform is. A professional platform caps what the creator's voice may do there (no swearing, slang or emojis, even if their voice
/// allows them elsewhere): the same creator doesn't write for LinkedIn the way they write for TikTok.
nonisolated enum PlatformRegister: Sendable {
    case casual, professional

    init(_ platform: Platform) {
        self = platform == .linkedin ? .professional : .casual
    }
}
