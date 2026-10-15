//
//  CoverExportState.swift
//  Cue Studio
//

import Foundation

/// Where the cover is after an export, told apart from the video's: a video saved to Photos stays saved whatever happens to its
/// cover, and a cover that couldn't be saved can be tried again or shared on its own.
enum CoverExportState: Equatable {
    /// The edit has no cover.
    case none
    case saving
    /// In Photos; `file` is the image, kept for Share until the export closes.
    case saved(file: URL)
    /// Not in Photos. `file` is the drawn image when drawing worked (Share still offers it), nil when the picture couldn't be
    /// drawn.
    case failed(message: String, file: URL?)

    /// The image to share, once it was drawn.
    var file: URL? {
        switch self {
        case .saved(let file): file
        case .failed(_, let file): file
        case .none, .saving: nil
        }
    }
}
