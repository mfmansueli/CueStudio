//
//  MaskDragTarget.swift
//  Cue Studio
//

import Foundation

/// What a finger moves on the preview while Mask is open: the mask over a still picture (another part of it shows), or the
/// picture under a still mask (reframed inside it). Moving the whole photo or video, mask and all, is the usual drag with the
/// panel closed.
enum MaskDragTarget: String, CaseIterable, Identifiable {
    case mask, picture

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mask: String(localized: "Mask")
        case .picture: String(localized: "Picture", comment: "Mask › Drag moves: the photo or video under the mask")
        }
    }
}
