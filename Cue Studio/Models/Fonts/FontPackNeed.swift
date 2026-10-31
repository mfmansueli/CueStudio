//
//  FontPackNeed.swift
//  Cue Studio
//

import Foundation

/// One library family at one weight a video's words need (`FontPackNeeds`): what `FontPackStore` downloads.
nonisolated struct FontPackNeed: Hashable, Sendable {
    var packID: String
    var weight: TextOverlayWeight
}
