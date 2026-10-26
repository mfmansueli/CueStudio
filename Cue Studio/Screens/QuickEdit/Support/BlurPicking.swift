//
//  BlurPicking.swift
//  Cue Studio
//

import Foundation

/// Blur area's first step: the faces in the frame under the playhead, numbered on the preview, to tap one (or every one but the
/// largest), or an area to draw for anything else.
struct BlurPicking: Equatable {
    var footage: BlurFootage
    /// The faces found there, largest first, on the footage's upright picture.
    var faces: [NormalizedBox] = []
    /// Still looking for them.
    var isSearching = true
}
