//
//  CustomFontRegistry.swift
//  Cue Studio
//

import Foundation
import Synchronization

/// The imported families this launch can draw, for the renderers (preview, export, cards), which run off the main actor:
/// `CustomFontStore` puts them here once their files are registered with Core Text. Only families whose files are on this
/// iPhone are here; a removed one stays (videos still use it) but isn't offered.
nonisolated final class CustomFontRegistry: Sendable {
    static let shared = CustomFontRegistry()

    private let families = Mutex<[CustomFontFamily]>([])

    func update(_ families: [CustomFontFamily]) {
        self.families.withLock { $0 = families }
    }

    /// The families a picker offers, newest first.
    var offeredFamilies: [String] {
        families.withLock { list in list.filter { !$0.isRemoved }.sorted { $0.importedAt > $1.importedAt }.map(\.name) }
    }

    func has(_ family: String) -> Bool {
        families.withLock { list in list.contains { $0.name == family } }
    }

    func weights(of family: String) -> [TextOverlayWeight]? {
        families.withLock { list in list.first { $0.name == family }?.weights }
    }

    func face(of family: String, weight: TextOverlayWeight) -> CustomFontFace? {
        families.withLock { list in list.first { $0.name == family }?.face(for: weight) }
    }
}
