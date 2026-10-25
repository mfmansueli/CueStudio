//
//  LibraryAssetKind.swift
//  Cue Studio
//

import Foundation

/// What a file of the creator's library is: a photo, a video, or a logo (a picture that goes small over the whole video,
/// keeping its transparency).
nonisolated enum LibraryAssetKind: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = LibraryAssetKind.photo

    case photo, video, logo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: String(localized: "Photo")
        case .video: String(localized: "Video")
        case .logo: String(localized: "Logo")
        }
    }

    var systemImage: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        case .logo: "seal"
        }
    }

    /// How it goes into a video's media.
    var mediaKind: MediaKind { self == .video ? .video : .photo }
}
