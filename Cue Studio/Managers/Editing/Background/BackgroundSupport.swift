//
//  BackgroundSupport.swift
//  Cue Studio
//

import CoreImage

/// Whether this iPhone can find people in video (Vision person segmentation), checked once by
/// asking for a mask of a small frame. The color key works everywhere: it's Core Image alone.
nonisolated enum BackgroundSupport {
    @concurrent
    static func canFindPeople() async -> Bool {
        let frame = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        return PersonMasker.mask(for: frame) != nil
    }
}
