//
//  BackgroundEffect.swift
//  Cue Studio
//

import Foundation

/// What a recording's background becomes in the edit: blurred, a color or a photo, behind the
/// person (found on the iPhone) or in place of a green or blue screen, with the creator where `person` puts them. Applied to the
/// recording's frames before anything is laid on top; the recording itself never changes. The cutout and the place also serve a
/// photo or video shown Behind you (`MediaLayout.behind`), whatever the style.
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
    /// Where the cut-out creator stands, moved and resized; nil (and edits from before it could move) as recorded.
    var person: PersonPlacement?

    /// Whether it changes the picture.
    var isActive: Bool {
        switch style {
        case .original: false
        case .image: imageFileName != nil
        case .blur, .color: true
        }
    }

    /// Where the creator stands, as recorded when it was never moved.
    var placement: PersonPlacement { person?.kept ?? .asRecorded }

    /// Whether the creator is moved or resized from where they were recorded.
    var movesPerson: Bool { !placement.isAsRecorded }
}
