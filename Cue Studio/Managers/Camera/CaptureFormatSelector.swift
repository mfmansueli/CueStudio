//
//  CaptureFormatSelector.swift
//  Cue Studio
//

import Foundation

/// Picks the device format for a resolution and frame rate. Pure so it can be tested without a camera.
nonisolated enum CaptureFormatSelector {
    /// Index of the best format, or nil when no format can record at `frameRate` at all.
    ///
    /// Order of preference: exact resolution at the frame rate, then the largest smaller resolution
    /// at the frame rate. Standard 8-bit formats win over HDR ones at the same size.
    static func bestIndex(in candidates: [CaptureFormatCandidate], resolution: VideoResolution, frameRate: FrameRate) -> Int? {
        let fps = Double(frameRate.rawValue)
        let supporting = candidates.indices.filter { candidates[$0].maxFrameRate >= fps }

        func best(_ indices: [Int]) -> Int? {
            indices.min { lhs, rhs in
                let a = candidates[lhs], b = candidates[rhs]
                if a.isStandardPixelFormat != b.isStandardPixelFormat { return a.isStandardPixelFormat }
                // Lower max frame rate usually means a less power-hungry, non-binned format.
                return a.maxFrameRate < b.maxFrameRate
            }
        }

        let exact = supporting.filter {
            candidates[$0].width == resolution.landscapeWidth && candidates[$0].height == resolution.landscapeHeight
        }
        if let index = best(exact) { return index }

        let smaller = supporting.filter {
            candidates[$0].width <= resolution.landscapeWidth && candidates[$0].height <= resolution.landscapeHeight
        }
        guard let largest = smaller.map({ candidates[$0].width * candidates[$0].height }).max() else { return nil }
        return best(smaller.filter { candidates[$0].width * candidates[$0].height == largest })
    }
}
