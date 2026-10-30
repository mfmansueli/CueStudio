//
//  MediaLibraryStore+AdditionAsset.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
extension MediaLibraryStore.Addition {
    /// The asset kept, whether it was added now or was already there.
    var asset: LibraryAsset {
        switch self {
        case .added(let asset), .alreadyThere(let asset): asset
        }
    }
}
