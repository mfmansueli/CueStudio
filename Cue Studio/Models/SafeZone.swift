//
//  SafeZone.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Part of the frame a platform covers with its own UI (buttons, caption, reply bar). Edges are in
/// points on the reference screen of `PlatformRules` and scale with the real screen.
nonisolated struct SafeZone: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case buttons, caption, title, profile, replyBar
    }

    var kind: Kind
    var left: Double?
    var right: Double?
    var top: Double
    var width: Double?
    var height: Double

    /// Button columns are labeled vertically.
    var isVertical: Bool { kind == .buttons }

    /// The zone on a screen of `size`, given the reference size the numbers were drawn on. A zone
    /// with only `right` and `width` hugs the right edge; one with `left` and `right` spans between.
    func frame(in size: CGSize, reference: CGSize) -> CGRect {
        guard reference.width > 0, reference.height > 0 else { return .zero }
        let sx = size.width / reference.width
        let sy = size.height / reference.height
        let zoneWidth: Double
        let x: Double
        switch (left, right, width) {
        case let (left?, right?, _):
            x = left
            zoneWidth = reference.width - left - right
        case let (left?, nil, width?):
            x = left
            zoneWidth = width
        case let (nil, right?, width?):
            x = reference.width - right - width
            zoneWidth = width
        default:
            x = 0
            zoneWidth = reference.width
        }
        return CGRect(x: x * sx, y: top * sy, width: max(0, zoneWidth) * sx, height: height * sy)
    }

    /// "TIKTOK BUTTONS", "CAPTION · REELS UI", "REPLY BAR · STORIES UI".
    func label(platformName: String) -> String {
        let name = platformName.uppercased()
        switch kind {
        case .buttons: return String(localized: "\(name) BUTTONS")
        case .caption: return String(localized: "CAPTION · \(name) UI")
        case .title: return String(localized: "TITLE · \(name) UI")
        case .profile: return String(localized: "PROFILE · \(name) UI")
        case .replyBar: return String(localized: "REPLY BAR · \(name) UI")
        }
    }
}
