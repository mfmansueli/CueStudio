//
//  CoverSource.swift
//  Cue Studio
//

import Foundation

/// Where a cover's picture comes from.
nonisolated enum CoverSource: Codable, Hashable, Sendable {
    /// A frame of the take itself, at this second: how covers were saved before montages. Read as a `CoverFrame` of the take
    /// (`frame`), so it keeps showing the same picture.
    case frame(TimeInterval)
    /// A frame of any recording in the edit (the take, another take or a video from Photos), with the clip it was picked on.
    case clipFrame(CoverFrame)
    /// A photo from the library, copied into `EditMediaFiles`.
    case photo(fileName: String)

    /// The frame it shows; nil for a photo.
    var frame: CoverFrame? {
        switch self {
        case .frame(let time): CoverFrame(sourceID: nil, segmentID: nil, time: time)
        case .clipFrame(let frame): frame
        case .photo: nil
        }
    }
}
