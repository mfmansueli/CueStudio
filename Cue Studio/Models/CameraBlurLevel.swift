//
//  CameraBlurLevel.swift
//  Cue Studio
//

import Foundation

/// "Camera blur" in Display: Off, Subtle, Soft or Medium. Kept light on purpose (about 6 pt at
/// most): it only calms the camera behind the Selfie text window so the words stand out, and the
/// creator should still see their framing. Preview only, never recorded.
nonisolated enum CameraBlurLevel: CaseIterable, Sendable {
    case off, subtle, soft, medium

    /// The slider's 0–20.
    init(amount: Double) {
        switch amount {
        case ...0: self = .off
        case ...5: self = .subtle
        case ...12: self = .soft
        default: self = .medium
        }
    }

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .subtle: String(localized: "Subtle")
        case .soft: String(localized: "Soft")
        case .medium: String(localized: "Medium")
        }
    }

    /// How much of the thinnest system material covers the camera, 0 to 1. Even Medium stays below
    /// a full ultra-thin material, which is the lightest blur the system draws.
    var strength: Double {
        switch self {
        case .off: 0
        case .subtle: 0.35
        case .soft: 0.6
        case .medium: 0.85
        }
    }
}
