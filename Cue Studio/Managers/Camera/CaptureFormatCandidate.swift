//
//  CaptureFormatCandidate.swift
//  Cue Studio
//

import Foundation

/// The parts of an `AVCaptureDevice.Format` that matter when picking one.
nonisolated struct CaptureFormatCandidate: Hashable, Sendable {
    /// Landscape dimensions, as the sensor reports them.
    var width: Int
    var height: Int
    var maxFrameRate: Double
    /// 8-bit 4:2:0 formats. 10-bit HDR formats record HDR video, which most editors and apps
    /// handle poorly, so they are only used when nothing else fits.
    var isStandardPixelFormat: Bool
}
