//
//  SafeGuideChoice.swift
//  Cue Studio
//

import Foundation

/// Which app's buttons the editor's safe zone guide shows, and the captions keep clear of: one platform's, or the generic guide
/// (clear of every vertical app measured, or the frame's own edges; `SafeGuideZones`). Saved with the edit as one word, a
/// platform's raw value or "generic", so a platform added later never breaks an older edit.
nonisolated enum SafeGuideChoice: Hashable, Sendable {
    case platform(Platform)
    case generic

    /// Chip and menu title: "TikTok", "Reels", "Generic".
    var label: String {
        switch self {
        case .platform(let platform): platform.label
        case .generic: String(localized: "Generic", comment: "Safe zone guide in the video editor that isn't any one app's")
        }
    }

    /// The guide's label on the preview: "TikTok · approximate" (apps move their buttons, so the guide never claims more).
    var approximateLabel: String {
        String(localized: "\(label) · approximate", comment: "Safe zone guide on the video editor's preview: the app it shows, e.g. TikTok")
    }

    /// For identifiers and for saving: "tiktok", "generic".
    var key: String {
        switch self {
        case .platform(let platform): platform.rawValue
        case .generic: "generic"
        }
    }

    init?(key: String) {
        if key == "generic" {
            self = .generic
        } else if let platform = Platform(rawValue: key) {
            self = .platform(platform)
        } else {
            return nil
        }
    }
}

nonisolated extension SafeGuideChoice: Codable {
    init(from decoder: Decoder) throws {
        let key = try decoder.singleValueContainer().decode(String.self)
        guard let choice = SafeGuideChoice(key: key) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown safe zone guide \(key)"))
        }
        self = choice
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
}
