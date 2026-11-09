//
//  BrandKitLogo.swift
//  Cue Studio
//

import Foundation

/// A kit's logo: its own file (`BrandKitFiles`), its shape, and where it goes on a video.
nonisolated struct BrandKitLogo: Codable, Hashable, Sendable {
    var fileName: String
    var aspect: Double
    var name: String
    var corner: BrandLogoCorner = .topRight
    /// Its width, as a share of the video's.
    var width = BrandKitLogo.defaultWidth

    static let defaultWidth = 0.2
}
