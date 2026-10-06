//
//  ProfileShareText.swift
//  Cue Studio
//

import Foundation

/// What "Share profile link" sends: the creator's handle in a line, since Cue has no web profile yet.
nonisolated enum ProfileShareText {
    static func text(for profile: CreatorProfile) -> String {
        String(localized: "Follow @\(profile.handle), made with Cue Studio")
    }
}
