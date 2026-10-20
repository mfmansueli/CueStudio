//
//  EyePatchResults.swift
//  Cue Studio
//

import CoreImage
import Foundation

/// The redrawn eyes' patches, filled from several threads at once (`EyeContactRenderer`), in the eyes' order.
///
/// `@unchecked Sendable`: `slots` is only touched under `lock`.
nonisolated final class EyePatchResults: @unchecked Sendable {
    private let lock = NSLock()
    private var slots: [CIImage?]

    init(count: Int) {
        slots = Array(repeating: nil, count: count)
    }

    func set(_ index: Int, _ image: CIImage) {
        lock.lock()
        slots[index] = image
        lock.unlock()
    }

    var images: [CIImage] {
        lock.lock()
        defer { lock.unlock() }
        return slots.compactMap { $0 }
    }
}
