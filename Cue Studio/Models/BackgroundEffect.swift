//
//  BackgroundEffect.swift
//  Cue Studio
//

import Foundation

/// What a recording's background becomes in the edit: blurred, a color or a photo, behind the
/// person (found on the iPhone) or in place of a green or blue screen. Applied to the recording's
/// frames before anything is laid on top; the recording itself never changes.
nonisolated struct BackgroundEffect: Codable, Hashable, Sendable {
    static let blurRange: ClosedRange<Double> = 0.1...1

    var style: BackgroundStyle = .original
    var cutout: BackgroundCutout = .person
    /// 0.1 to 1: how strong the blur is.
    var blur: Double = 0.5
    var color: OverlayColor = .black
    /// The photo's name in `EditMediaFiles`, for `.image`.
    var imageFileName: String?
    var key: ChromaKey = .green

    /// Whether it changes the picture.
    var isActive: Bool {
        switch style {
        case .original: false
        case .image: imageFileName != nil
        case .blur, .color: true
        }
    }
}
