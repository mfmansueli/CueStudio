//
//  VoyageGalaxy.swift
//  Cue Studio
//

import SwiftUI

/// A platform's galaxy on the 1.3 board: the art it is drawn from (`GalaxyArt`), where its name sits, and the layers of the board's motion
/// that give birth to it (it grows from a point, with a ring), fade its name in and light its ring.
struct VoyageGalaxy {
    let platform: Platform
    /// The key of its art in `galaxies.json`.
    let key: String
    /// The layers of `1.3_voyage` that animate it: birth, the ring of its birth and its name.
    let birth: String
    let ring: String
    let name: String
    /// Where its name is centred on the board, and how big it is.
    let nameCentre: CGPoint
    let nameSize: CGFloat

    /// Back to front, as the board draws them: the platform of the demo is last, so it is on top.
    static let all: [VoyageGalaxy] = [
        VoyageGalaxy(platform: .reels, key: "reels", birth: "L7", ring: "L33", name: "L29", nameCentre: CGPoint(x: 147, y: 279), nameSize: 9.5),
        VoyageGalaxy(platform: .youtube, key: "youtube", birth: "L9", ring: "L34", name: "L32", nameCentre: CGPoint(x: 212, y: 349), nameSize: 9.5),
        VoyageGalaxy(platform: .shorts, key: "shorts", birth: "L11", ring: "L36", name: "L30", nameCentre: CGPoint(x: 324, y: 443), nameSize: 9.5),
        VoyageGalaxy(platform: .linkedin, key: "linkedin", birth: "L13", ring: "L37", name: "L31", nameCentre: CGPoint(x: 54, y: 373), nameSize: 9.5),
        VoyageGalaxy(platform: .tiktok, key: "tiktok", birth: "L16", ring: "L35", name: "L28", nameCentre: CGPoint(x: 298, y: 337), nameSize: 10),
    ]

    static func of(_ platform: Platform) -> VoyageGalaxy? { all.first { $0.platform == platform } }

    /// Where the galaxy sits on the board, from its art.
    var centre: CGPoint {
        guard let art = GalaxyLibrary.art?.socials[key] else { return .zero }
        return CGPoint(x: art.center[0], y: art.center[1])
    }
}
